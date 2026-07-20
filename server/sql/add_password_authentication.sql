-- Adds optional email + password sign-in alongside the existing
-- WhatsApp-inbound flow. Both columns are nullable: existing accounts keep
-- working exactly as before until they set a password.

alter table if exists public.users
  add column if not exists email text;

alter table if exists public.users
  add column if not exists password_hash text;

create unique index if not exists users_email_unique_idx
  on public.users (lower(email))
  where email is not null;

notify pgrst, 'reload schema';
