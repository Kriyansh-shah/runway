-- Safety fixes for splits and settle-ups (security review, 2026-10-22).
--
-- 1. Anyone in a split can delete it, not just whoever added or paid it,
--    so nobody can be stuck with a debt they never agreed to.
-- 2. Either person in a settle-up can remove it, so "I paid you" can't
--    quietly wipe a debt the other person is still owed.
-- 3. A split outside a squad needs everyone in it to be friends with each
--    other. Before, a split could put two strangers together, and after
--    that they could see each other's profile.
-- 4. At most 60 splits and 60 settle-ups an hour per person, so a friend
--    can't flood someone's budget.

create index if not exists shared_expenses_created_by_at_idx
  on public.shared_expenses (created_by, created_at);
create index if not exists settlements_created_by_at_idx
  on public.settlements (created_by, created_at);

create or replace function public.add_shared_expense(
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
  if (select count(*) from public.shared_expenses e
      where e.created_by = me and e.created_at > now() - interval '1 hour') >= 60 then
    raise exception 'too_many_splits';
  end if;
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
    -- Outside a squad, everyone already in the list must be friends with
    -- this person too (inside one, they all share the squad).
    if squad is null and exists (
      select 1 from unnest(people) other
      where other <> me and not private.are_friends(other, person)
    ) then
      raise exception 'not_all_friends';
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

-- Anyone in a split (sharing it or paying it) can delete it for everyone.
create or replace function public.delete_shared_expense(target uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  update public.shared_expenses e
    set deleted_at = now()
    where e.id = target and e.deleted_at is null
      and (me in (e.created_by, e.paid_by) or exists (
        select 1 from public.expense_shares s
        where s.expense_id = e.id and s.user_id = me
      ));
  if not found then raise exception 'not_allowed'; end if;
end;
$$;

create or replace function public.record_settlements(items jsonb)
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
  if (select count(*) from public.settlements s
      where s.created_by = me and s.created_at > now() - interval '1 hour')
     + jsonb_array_length(items) > 60 then
    raise exception 'too_many_settlements';
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

-- Either person in a settle-up can remove it.
create or replace function public.delete_settlement(target uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  update public.settlements s set deleted_at = now()
    where s.id = target and s.deleted_at is null
      and me in (s.from_user, s.to_user, s.created_by);
  if not found then raise exception 'not_allowed'; end if;
end;
$$;

-- "create or replace" keeps the existing grants; restated so this file
-- reads on its own.
revoke execute on function
  public.add_shared_expense(uuid, text, text, int, uuid, text, jsonb),
  public.delete_shared_expense(uuid), public.record_settlements(jsonb),
  public.delete_settlement(uuid)
  from public, anon;
grant execute on function
  public.add_shared_expense(uuid, text, text, int, uuid, text, jsonb),
  public.delete_shared_expense(uuid), public.record_settlements(jsonb),
  public.delete_settlement(uuid)
  to authenticated;
