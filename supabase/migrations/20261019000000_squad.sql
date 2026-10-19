-- Squad: small groups of friends who see each other's first name, emoji,
-- logging streak and no-delivery-week dots. Never money: balances,
-- expenses and budgets stay on the phone and have no table here.
--
-- Everyone signs in (Google via Supabase Auth). Row-level security is on
-- for every table; joining and inviting go through the functions at the
-- bottom so invite rules can't be skipped.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null check (char_length(first_name) between 1 and 30),
  emoji text not null default '😎' check (char_length(emoji) between 1 and 8),
  streak int not null default 0 check (streak between 0 and 100000),
  -- One per elapsed day of this week's challenge: true = delivery-free.
  no_delivery_days boolean[] not null default '{}'
    check (cardinality(no_delivery_days) <= 7),
  updated_at timestamptz not null default now()
);

create table public.squads (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.squad_members (
  squad_id uuid not null references public.squads (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (squad_id, user_id)
);
create index squad_members_user_id_idx on public.squad_members (user_id);

create table public.squad_invites (
  code text primary key,
  squad_id uuid not null references public.squads (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  uses int not null default 0,
  max_uses int not null default 8,
  revoked boolean not null default false
);
create index squad_invites_squad_id_idx on public.squad_invites (squad_id);
create index squad_invites_created_by_idx on public.squad_invites (created_by);
create index squads_created_by_idx on public.squads (created_by);

-- Failed invite codes, to slow down guessing.
create table public.join_attempts (
  user_id uuid not null references public.profiles (id) on delete cascade,
  at timestamptz not null default now()
);
create index join_attempts_user_at_idx on public.join_attempts (user_id, at);

alter table public.profiles enable row level security;
alter table public.squads enable row level security;
alter table public.squad_members enable row level security;
alter table public.squad_invites enable row level security;
alter table public.join_attempts enable row level security;

-- Helpers for policies. Security definer so checking membership doesn't
-- recurse through squad_members' own policy.
create function public.is_squad_member(target_squad uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.squad_members
    where squad_id = target_squad and user_id = (select auth.uid())
  );
$$;

create function public.shares_squad_with(other uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.squad_members mine
    join public.squad_members theirs using (squad_id)
    where mine.user_id = (select auth.uid()) and theirs.user_id = other
  );
$$;

-- profiles: yours to write; readable by you and your squadmates.
create policy "read own and squadmates' profiles" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or public.shares_squad_with(id));
create policy "create own profile" on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));
create policy "update own profile" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- squads, members, invites: visible to members only.
create policy "members read their squads" on public.squads
  for select to authenticated
  using (public.is_squad_member(id));
create policy "members read their squad's members" on public.squad_members
  for select to authenticated
  using (public.is_squad_member(squad_id));
create policy "leave a squad" on public.squad_members
  for delete to authenticated
  using (user_id = (select auth.uid()));
create policy "members read their squad's invites" on public.squad_invites
  for select to authenticated
  using (public.is_squad_member(squad_id));
-- join_attempts: no policies, so only the functions below touch it.

-- A squad with nobody left in it is deleted, with its invites.
create function public.delete_empty_squad()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (select 1 from public.squad_members where squad_id = old.squad_id) then
    delete from public.squads where id = old.squad_id;
  end if;
  return null;
end;
$$;
create trigger squad_members_cleanup
  after delete on public.squad_members
  for each row execute function public.delete_empty_squad();

-- Six characters without look-alikes (no 0/O, 1/I/L), from
-- gen_random_uuid's strong randomness.
create function public.new_invite_code()
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea;
  candidate text;
begin
  loop
    bytes := uuid_send(gen_random_uuid());
    candidate := '';
    for i in 0..5 loop
      candidate := candidate || substr(alphabet, 1 + get_byte(bytes, i) % 31, 1);
    end loop;
    exit when not exists (select 1 from public.squad_invites i where i.code = candidate);
  end loop;
  return candidate;
end;
$$;

-- Starts a squad with you in it and returns its first invite code.
create function public.create_squad(squad_name text)
returns table (squad_id uuid, code text)
language plpgsql security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  me uuid := (select auth.uid());
  new_squad uuid;
  new_code text;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from public.profiles where id = me) then
    raise exception 'no_profile';
  end if;
  if (select count(*) from public.squad_members where user_id = me) >= 5 then
    raise exception 'too_many_squads';
  end if;
  insert into public.squads (name, created_by)
    values (trim(squad_name), me) returning id into new_squad;
  insert into public.squad_members (squad_id, user_id) values (new_squad, me);
  new_code := public.new_invite_code();
  insert into public.squad_invites (code, squad_id, created_by)
    values (new_code, new_squad, me);
  return query select new_squad, new_code;
end;
$$;

-- A working invite code for a squad you're in: the newest one still
-- valid, or a fresh one.
create function public.squad_invite(target_squad uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  found text;
begin
  if not public.is_squad_member(target_squad) then
    raise exception 'not_a_member';
  end if;
  select i.code into found from public.squad_invites i
    where i.squad_id = target_squad and not i.revoked
      and i.expires_at > now() + interval '1 day' and i.uses < i.max_uses
    order by i.created_at desc limit 1;
  if found is not null then return found; end if;
  if (select count(*) from public.squad_invites i
      where i.squad_id = target_squad and i.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many_invites';
  end if;
  found := public.new_invite_code();
  insert into public.squad_invites (code, squad_id, created_by)
    values (found, target_squad, me);
  return found;
end;
$$;

-- Joins the squad an invite code belongs to and returns its id, or null
-- for a wrong, expired or used-up code (returned, not raised, so the
-- failed attempt is kept). Accepting the invite is the consent, so nobody
-- has to approve it.
create function public.join_squad(invite_code text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  clean text := upper(regexp_replace(coalesce(invite_code, ''), '[^A-Za-z0-9]', '', 'g'));
  invite public.squad_invites;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from public.profiles where id = me) then
    raise exception 'no_profile';
  end if;
  if (select count(*) from public.join_attempts
      where user_id = me and at > now() - interval '1 hour') >= 10 then
    raise exception 'too_many_attempts';
  end if;

  select * into invite from public.squad_invites where code = clean for update;
  if invite.code is null or invite.revoked or invite.expires_at <= now()
     or invite.uses >= invite.max_uses then
    insert into public.join_attempts (user_id) values (me);
    return null;
  end if;

  if exists (select 1 from public.squad_members
             where squad_id = invite.squad_id and user_id = me) then
    return invite.squad_id;
  end if;
  if (select count(*) from public.squad_members where squad_id = invite.squad_id) >= 8 then
    raise exception 'squad_full';
  end if;
  if (select count(*) from public.squad_members where user_id = me) >= 5 then
    raise exception 'too_many_squads';
  end if;

  insert into public.squad_members (squad_id, user_id) values (invite.squad_id, me);
  update public.squad_invites set uses = uses + 1 where code = invite.code;
  return invite.squad_id;
end;
$$;

-- Only signed-in people can call these; trigger and code helpers aren't
-- callable at all.
revoke execute on function
  public.is_squad_member(uuid), public.shares_squad_with(uuid),
  public.delete_empty_squad(), public.new_invite_code(),
  public.create_squad(text), public.squad_invite(uuid), public.join_squad(text)
  from public, anon;
revoke execute on function
  public.delete_empty_squad(), public.new_invite_code()
  from authenticated;
grant execute on function
  public.is_squad_member(uuid), public.shares_squad_with(uuid),
  public.create_squad(text), public.squad_invite(uuid), public.join_squad(text)
  to authenticated;
