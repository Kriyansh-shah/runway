-- The membership checks used by policies don't need to be callable from
-- the API, so they move to a schema the API doesn't expose.
create schema if not exists private;
grant usage on schema private to authenticated;

alter function public.is_squad_member(uuid) set schema private;
alter function public.shares_squad_with(uuid) set schema private;
revoke execute on function
  private.is_squad_member(uuid), private.shares_squad_with(uuid)
  from public, anon;
grant execute on function
  private.is_squad_member(uuid), private.shares_squad_with(uuid)
  to authenticated;

-- squad_invite called the helper by its old name.
create or replace function public.squad_invite(target_squad uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  found text;
begin
  if not private.is_squad_member(target_squad) then
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
