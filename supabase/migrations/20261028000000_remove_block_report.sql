-- Remove, block and report (App Store guideline 1.2, user-generated content).
--
-- 1. Remove: a squad's owner can remove someone from it. The owner is
--    whoever started the squad while they're still in it, then whoever has
--    been in it longest. Removed people can't rejoin with an invite code.
-- 2. Block: blocking someone unfriends you, and from then on neither of
--    you sees the other (in squads, friends or profiles), can add the
--    other back, split or settle up together, or join a squad the other
--    is in. Old splits stay, but the other person shows as "Someone".
-- 3. Report: a person (and optionally the squad it happened in, for a
--    squad name). Reports are only readable from the Supabase dashboard.

create table public.blocks (
  blocker uuid not null references public.profiles (id) on delete cascade,
  blocked uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index blocks_blocked_idx on public.blocks (blocked);

create table public.squad_removals (
  squad_id uuid not null references public.squads (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  removed_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (squad_id, user_id)
);
create index squad_removals_user_idx on public.squad_removals (user_id);
create index squad_removals_removed_by_idx on public.squad_removals (removed_by);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid references public.profiles (id) on delete set null,
  reported uuid references public.profiles (id) on delete set null,
  squad_id uuid references public.squads (id) on delete set null,
  reason text not null
    check (reason in ('name', 'squad_name', 'harassment', 'spam', 'other')),
  details text check (char_length(details) <= 500),
  created_at timestamptz not null default now(),
  check (reported is not null or squad_id is not null)
);
create index reports_reporter_at_idx on public.reports (reporter, created_at);
create index reports_reported_idx on public.reports (reported);
create index reports_squad_idx on public.reports (squad_id);

alter table public.blocks enable row level security;
alter table public.squad_removals enable row level security;
alter table public.reports enable row level security;

-- You see who you've blocked (to unblock them), never who blocked you.
create policy "see who you blocked" on public.blocks
  for select to authenticated
  using (blocker = (select auth.uid()));
-- squad_removals and reports: no policies, only the functions below.

create function private.blocked_between(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.blocks
    where (blocker = a and blocked = b) or (blocker = b and blocked = a)
  );
$$;

create function private.squad_owner(target uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select s.created_by from public.squads s
     join public.squad_members m on m.squad_id = s.id and m.user_id = s.created_by
     where s.id = target),
    (select m.user_id from public.squad_members m
     where m.squad_id = target order by m.joined_at, m.user_id limit 1)
  );
$$;

revoke execute on function
  private.blocked_between(uuid, uuid), private.squad_owner(uuid)
  from public, anon;
grant execute on function
  private.blocked_between(uuid, uuid), private.squad_owner(uuid)
  to authenticated;

-- Blocked people aren't friends, so they can't split or settle up.
create or replace function private.are_friends(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select a <> b and not private.blocked_between(a, b) and (
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

-- Hide blocked people from each other.
drop policy "read own, friends' and split partners' profiles" on public.profiles;
create policy "read own, friends' and split partners' profiles" on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or (
      not private.blocked_between((select auth.uid()), id)
      and (
        private.are_friends((select auth.uid()), id)
        or private.shares_expense_with(id)
      )
    )
  );

drop policy "members read their squad's members" on public.squad_members;
create policy "members read their squad's members" on public.squad_members
  for select to authenticated
  using (
    private.is_squad_member(squad_id)
    and not private.blocked_between((select auth.uid()), user_id)
  );

-- Removes someone from a squad you own.
create function public.remove_squad_member(squad uuid, person uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if private.squad_owner(squad) is distinct from me then
    raise exception 'not_owner';
  end if;
  if person = me then raise exception 'bad_person'; end if;
  delete from public.squad_members m where m.squad_id = squad and m.user_id = person;
  if not found then raise exception 'not_in_squad'; end if;
  insert into public.squad_removals (squad_id, user_id, removed_by)
    values (squad, person, me)
    on conflict (squad_id, user_id) do update set removed_by = me, created_at = now();
end;
$$;

create function public.block_user(person uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if person is null or person = me then raise exception 'bad_person'; end if;
  if (select count(*) from public.blocks where blocker = me) >= 500 then
    raise exception 'too_many_blocks';
  end if;
  insert into public.blocks (blocker, blocked) values (me, person)
    on conflict do nothing;
  delete from public.friendships
    where user_a = least(me, person) and user_b = greatest(me, person);
end;
$$;

create function public.unblock_user(person uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  delete from public.blocks
    where blocker = (select auth.uid()) and blocked = person;
end;
$$;

-- Names of the people you've blocked, for the unblock list. Their
-- profiles are hidden from you otherwise.
create function public.blocked_people()
returns table (id uuid, first_name text, emoji text)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.first_name, p.emoji
  from public.blocks b join public.profiles p on p.id = b.blocked
  where b.blocker = (select auth.uid())
  order by b.created_at desc;
$$;

create function public.report(
  person uuid,
  squad uuid,
  reason text,
  details text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if person is null and squad is null then raise exception 'bad_report'; end if;
  if person = me then raise exception 'bad_person'; end if;
  -- Only people and squads you know: a current or past squadmate, a
  -- friend, someone you've split with, or someone you've blocked.
  if person is not null and not (
    private.are_friends(me, person)
    or private.shares_expense_with(person)
    or exists (select 1 from public.blocks b where b.blocker = me and b.blocked = person)
  ) then
    raise exception 'bad_person';
  end if;
  if squad is not null and not private.is_squad_member(squad) then
    raise exception 'not_a_member';
  end if;
  if (select count(*) from public.reports r
      where r.reporter = me and r.created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many_reports';
  end if;
  insert into public.reports (reporter, reported, squad_id, reason, details)
    values (me, person, squad, reason, nullif(trim(coalesce(details, '')), ''));
end;
$$;

-- Joining: not if you were removed, or if anyone in the squad has blocked
-- you or been blocked by you.
create or replace function public.join_squad(invite_code text)
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
  if exists (select 1 from public.squad_removals
             where squad_id = invite.squad_id and user_id = me)
     or exists (select 1 from public.squad_members m
                where m.squad_id = invite.squad_id
                  and private.blocked_between(me, m.user_id)) then
    raise exception 'cant_join';
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

-- Adding a friend: not someone you've blocked or who blocked you. The
-- code is used up the same way, so a block can't be detected by trying.
create or replace function public.add_friend(friend_code text)
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
  if private.blocked_between(me, invite.created_by) then
    insert into public.join_attempts (user_id) values (me);
    return null;
  end if;
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

revoke execute on function
  public.remove_squad_member(uuid, uuid), public.block_user(uuid),
  public.unblock_user(uuid), public.blocked_people(),
  public.report(uuid, uuid, text, text)
  from public, anon;
grant execute on function
  public.remove_squad_member(uuid, uuid), public.block_user(uuid),
  public.unblock_user(uuid), public.blocked_people(),
  public.report(uuid, uuid, text, text)
  to authenticated;
