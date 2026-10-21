-- Friends and synced splits (Splitwise-style).
--
-- Friends are people who share a squad with you, or who added each other
-- with a friend code. Splits ("shared expenses") are between friends,
-- optionally inside a squad, and only the people in a split can see it,
-- amounts included. Budgets and balances are never stored here: balances
-- are worked out on the phone from the splits and settle-ups.
--
-- Reads go through row-level security; every write goes through a
-- function below, so the rules (shares add up, only friends, only squad
-- members in a squad split) can't be skipped.

create table public.friendships (
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index friendships_user_b_idx on public.friendships (user_b);

create table public.friend_invites (
  code text primary key,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  uses int not null default 0,
  max_uses int not null default 20,
  revoked boolean not null default false
);
create index friend_invites_created_by_idx on public.friend_invites (created_by);

alter table public.squads add column simplify_debts boolean not null default true;

create table public.shared_expenses (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid references public.squads (id) on delete set null,
  created_by uuid references public.profiles (id) on delete set null,
  paid_by uuid not null references public.profiles (id) on delete cascade,
  description text not null check (char_length(description) between 1 and 80),
  category text not null default 'other' check (char_length(category) <= 30),
  split_kind text not null default 'equal'
    check (split_kind in ('equal', 'exact', 'percent', 'shares')),
  total_cents int not null check (total_cents between 1 and 10000000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index shared_expenses_squad_idx on public.shared_expenses (squad_id);
create index shared_expenses_paid_by_idx on public.shared_expenses (paid_by);
create index shared_expenses_created_by_idx on public.shared_expenses (created_by);

create table public.expense_shares (
  expense_id uuid not null references public.shared_expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  share_cents int not null check (share_cents between 0 and 10000000),
  primary key (expense_id, user_id)
);
create index expense_shares_user_idx on public.expense_shares (user_id);

-- "from_user paid to_user": a settle-up, inside a squad's books or not.
create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid references public.squads (id) on delete set null,
  from_user uuid not null references public.profiles (id) on delete cascade,
  to_user uuid not null references public.profiles (id) on delete cascade,
  amount_cents int not null check (amount_cents between 1 and 10000000),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (from_user <> to_user)
);
create index settlements_from_idx on public.settlements (from_user);
create index settlements_to_idx on public.settlements (to_user);
create index settlements_squad_idx on public.settlements (squad_id);
create index settlements_created_by_idx on public.settlements (created_by);

alter table public.friendships enable row level security;
alter table public.friend_invites enable row level security;
alter table public.shared_expenses enable row level security;
alter table public.expense_shares enable row level security;
alter table public.settlements enable row level security;

-- Helpers (not exposed through the API).
create function private.are_friends(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select a <> b and (
    exists (
      select 1 from public.friendships
      where user_a = least(a, b) and user_b = greatest(a, b)
    )
    or exists (
      select 1
      from public.squad_members x
      join public.squad_members y using (squad_id)
      where x.user_id = a and y.user_id = b
    )
  );
$$;

create function private.in_expense(target uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.expense_shares
    where expense_id = target and user_id = (select auth.uid())
  ) or exists (
    select 1 from public.shared_expenses
    where id = target and paid_by = (select auth.uid())
  );
$$;

-- Someone you've split with stays visible by name even if you're no
-- longer friends, so old splits still read right.
create function private.shares_expense_with(other uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.expense_shares mine
    join public.expense_shares theirs using (expense_id)
    where mine.user_id = (select auth.uid()) and theirs.user_id = other
  ) or exists (
    select 1 from public.settlements
    where (from_user = (select auth.uid()) and to_user = other)
       or (to_user = (select auth.uid()) and from_user = other)
  );
$$;

revoke execute on function
  private.are_friends(uuid, uuid), private.in_expense(uuid),
  private.shares_expense_with(uuid)
  from public, anon;
grant execute on function
  private.are_friends(uuid, uuid), private.in_expense(uuid),
  private.shares_expense_with(uuid)
  to authenticated;

-- Profiles: also readable by friends and people you've split with.
drop policy "read own and squadmates' profiles" on public.profiles;
create policy "read own, friends' and split partners' profiles" on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or private.are_friends((select auth.uid()), id)
    or private.shares_expense_with(id)
  );

create policy "see your friendships" on public.friendships
  for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));
create policy "unfriend" on public.friendships
  for delete to authenticated
  using ((select auth.uid()) in (user_a, user_b));

create policy "see your friend codes" on public.friend_invites
  for select to authenticated
  using (created_by = (select auth.uid()));

create policy "people in a split see it" on public.shared_expenses
  for select to authenticated
  using (private.in_expense(id));
create policy "people in a split see its shares" on public.expense_shares
  for select to authenticated
  using (private.in_expense(expense_id));
create policy "the two people see a settle-up" on public.settlements
  for select to authenticated
  using ((select auth.uid()) in (from_user, to_user));

-- A friend code to share; the newest still-valid one, or a fresh one.
create function public.friend_code()
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  found text;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from public.profiles where id = me) then
    raise exception 'no_profile';
  end if;
  select i.code into found from public.friend_invites i
    where i.created_by = me and not i.revoked
      and i.expires_at > now() + interval '1 day' and i.uses < i.max_uses
    order by i.created_at desc limit 1;
  if found is not null then return found; end if;
  if (select count(*) from public.friend_invites i
      where i.created_by = me and i.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many_invites';
  end if;
  loop
    found := public.new_invite_code();
    exit when not exists (select 1 from public.friend_invites i where i.code = found);
  end loop;
  insert into public.friend_invites (code, created_by) values (found, me);
  return found;
end;
$$;

-- Adds the person whose friend code this is. Returns their id, or null for
-- a wrong, expired or used-up code (kept as a failed attempt).
create function public.add_friend(friend_code text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  clean text := upper(regexp_replace(coalesce(friend_code, ''), '[^A-Za-z0-9]', '', 'g'));
  invite public.friend_invites;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from public.profiles where id = me) then
    raise exception 'no_profile';
  end if;
  if (select count(*) from public.join_attempts
      where user_id = me and at > now() - interval '1 hour') >= 10 then
    raise exception 'too_many_attempts';
  end if;
  select * into invite from public.friend_invites where code = clean for update;
  if invite.code is null or invite.revoked or invite.expires_at <= now()
     or invite.uses >= invite.max_uses then
    insert into public.join_attempts (user_id) values (me);
    return null;
  end if;
  if invite.created_by = me then raise exception 'own_code'; end if;
  if (select count(*) from public.friendships where me in (user_a, user_b)) >= 500 then
    raise exception 'too_many_friends';
  end if;
  insert into public.friendships (user_a, user_b)
    values (least(me, invite.created_by), greatest(me, invite.created_by))
    on conflict do nothing;
  update public.friend_invites set uses = uses + 1 where code = invite.code;
  return invite.created_by;
end;
$$;

-- Splits [total] between people. [shares] is a JSON list of
-- {"user_id": uuid, "share_cents": int}; it must add up to the total and
-- include the payer (with 0 if they paid for others only). Everyone must
-- be you or your friend, and inside a squad, a member of it.
create function public.add_shared_expense(
  squad uuid,
  description text,
  category text,
  total_cents int,
  paid_by uuid,
  split_kind text,
  shares jsonb
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
#variable_conflict use_variable
declare
  me uuid := (select auth.uid());
  share jsonb;
  person uuid;
  amount int;
  people uuid[] := '{}';
  sum_cents bigint := 0;
  new_id uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if jsonb_typeof(shares) <> 'array' or jsonb_array_length(shares) < 2
     or jsonb_array_length(shares) > 20 then
    raise exception 'bad_shares';
  end if;
  for share in select * from jsonb_array_elements(shares) loop
    person := (share ->> 'user_id')::uuid;
    amount := (share ->> 'share_cents')::int;
    if person is null or amount is null or amount < 0 then
      raise exception 'bad_shares';
    end if;
    if person = any (people) then raise exception 'bad_shares'; end if;
    if person <> me and not private.are_friends(me, person) then
      raise exception 'not_friends';
    end if;
    if squad is not null and not exists (
      select 1 from public.squad_members m
      where m.squad_id = squad and m.user_id = person
    ) then
      raise exception 'not_in_squad';
    end if;
    people := people || person;
    sum_cents := sum_cents + amount;
  end loop;
  if sum_cents <> total_cents then raise exception 'shares_dont_add_up'; end if;
  if not (paid_by = any (people)) then raise exception 'payer_not_in_split'; end if;
  if not (me = any (people)) then raise exception 'not_in_split'; end if;

  insert into public.shared_expenses
    (squad_id, created_by, paid_by, description, category, split_kind, total_cents)
    values (squad, me, paid_by, trim(description), coalesce(category, 'other'),
            split_kind, total_cents)
    returning id into new_id;
  insert into public.expense_shares (expense_id, user_id, share_cents)
    select new_id, (s ->> 'user_id')::uuid, (s ->> 'share_cents')::int
    from jsonb_array_elements(shares) s;
  return new_id;
end;
$$;

-- Whoever added a split, or paid it, can delete it for everyone in it.
create function public.delete_shared_expense(target uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  update public.shared_expenses
    set deleted_at = now()
    where id = target and deleted_at is null and me in (created_by, paid_by);
  if not found then raise exception 'not_allowed'; end if;
end;
$$;

-- Records settle-ups. [items] is a JSON list of
-- {"squad_id": uuid|null, "from_user": uuid, "to_user": uuid,
--  "amount_cents": int}; you must be one of the two people each time,
-- and the other must be your friend (inside a squad, a member of it).
create function public.record_settlements(items jsonb)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  item jsonb;
  from_id uuid;
  to_id uuid;
  squad uuid;
  amount int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items) < 1
     or jsonb_array_length(items) > 20 then
    raise exception 'bad_items';
  end if;
  for item in select * from jsonb_array_elements(items) loop
    from_id := (item ->> 'from_user')::uuid;
    to_id := (item ->> 'to_user')::uuid;
    squad := nullif(item ->> 'squad_id', '')::uuid;
    amount := (item ->> 'amount_cents')::int;
    if from_id is null or to_id is null or amount is null or amount <= 0
       or from_id = to_id or not (me in (from_id, to_id)) then
      raise exception 'bad_items';
    end if;
    if not private.are_friends(from_id, to_id) then raise exception 'not_friends'; end if;
    if squad is not null and (
      select count(*) from public.squad_members m
      where m.squad_id = squad and m.user_id in (from_id, to_id)
    ) < 2 then
      raise exception 'not_in_squad';
    end if;
    insert into public.settlements (squad_id, from_user, to_user, amount_cents, created_by)
      values (squad, from_id, to_id, amount, me);
  end loop;
end;
$$;

-- Undo a settle-up you recorded.
create function public.delete_settlement(target uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.settlements set deleted_at = now()
    where id = target and deleted_at is null and created_by = (select auth.uid());
  if not found then raise exception 'not_allowed'; end if;
end;
$$;

-- Any member can turn a squad's "simplify debts" on or off.
create function public.set_simplify_debts(squad uuid, simplify boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not private.is_squad_member(squad) then raise exception 'not_a_member'; end if;
  update public.squads set simplify_debts = simplify where id = squad;
end;
$$;

revoke execute on function
  public.friend_code(), public.add_friend(text),
  public.add_shared_expense(uuid, text, text, int, uuid, text, jsonb),
  public.delete_shared_expense(uuid), public.record_settlements(jsonb),
  public.delete_settlement(uuid), public.set_simplify_debts(uuid, boolean)
  from public, anon;
grant execute on function
  public.friend_code(), public.add_friend(text),
  public.add_shared_expense(uuid, text, text, int, uuid, text, jsonb),
  public.delete_shared_expense(uuid), public.record_settlements(jsonb),
  public.delete_settlement(uuid), public.set_simplify_debts(uuid, boolean)
  to authenticated;
