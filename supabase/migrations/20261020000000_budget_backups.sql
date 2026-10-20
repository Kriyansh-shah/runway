-- Budget sync: one encrypted copy of each person's budget. It's sealed on
-- the device with a key from a passphrase only they know (AES-256-GCM,
-- PBKDF2), so this table holds ciphertext the server can't read. Only the
-- owner can see or change their row.
create table public.budget_backups (
  user_id uuid primary key references auth.users (id) on delete cascade,
  version bigint not null check (version > 0),
  ciphertext text not null check (char_length(ciphertext) <= 10000000),
  nonce text not null check (char_length(nonce) <= 64),
  salt text not null check (char_length(salt) <= 64),
  iterations int not null check (iterations between 100000 and 10000000),
  updated_at timestamptz not null default now()
);

alter table public.budget_backups enable row level security;

create policy "read own budget" on public.budget_backups
  for select to authenticated
  using (user_id = (select auth.uid()));
create policy "create own budget" on public.budget_backups
  for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "update own budget" on public.budget_backups
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "delete own budget" on public.budget_backups
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- The server sets the time, so devices with wrong clocks can't win
-- "most recent change" unfairly.
create function public.touch_budget_backup()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger budget_backups_touch
  before insert or update on public.budget_backups
  for each row execute function public.touch_budget_backup();
revoke execute on function public.touch_budget_backup() from public, anon, authenticated;
