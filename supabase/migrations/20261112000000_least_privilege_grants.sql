-- Least-privilege table grants (security review, 2026-11-12).
--
-- Supabase grants every table to anon and authenticated by default, so
-- row-level security was the only thing standing between the API and the
-- data. RLS stays the main guard; these grants are a second lock, so a
-- policy added by mistake later can't open a table on its own.
--
-- anon (the public app key, not signed in) gets no table access at all,
-- except an empty read of budget_backups for the keep-awake ping
-- (.github/workflows/supabase-keepalive.yml; RLS returns no rows).
--
-- authenticated gets exactly what the app does directly; everything else
-- goes through the security-definer functions, which check who's calling.
--
-- From now on new tables and functions start with no access for anon or
-- authenticated: a migration must grant what it needs.

revoke all on all tables in schema public from anon, authenticated;

grant select on public.budget_backups to anon;

grant select on public.blocks to authenticated;
grant select, insert, update, delete on public.budget_backups to authenticated;
grant select on public.expense_shares to authenticated;
grant select on public.friend_invites to authenticated;
grant select, delete on public.friendships to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select on public.settlements to authenticated;
grant select on public.shared_expenses to authenticated;
grant select on public.squad_invites to authenticated;
grant select, delete on public.squad_members to authenticated;
grant select on public.squads to authenticated;
-- join_attempts, reports, squad_removals: only the functions touch them.

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated, public;
