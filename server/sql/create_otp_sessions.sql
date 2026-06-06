create extension if not exists pgcrypto;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'otp_purpose_enum'
  ) then
    create type public.otp_purpose_enum as enum (
      'register',
      'login',
      'reset_password',
      'verify_phone'
    );
  end if;
end $$;

create table if not exists public.otp_sessions (
  id uuid primary key default gen_random_uuid(),
  phone_number text not null,
  purpose public.otp_purpose_enum not null,
  status text not null default 'pending' check (status in ('pending', 'verified', 'expired', 'cancelled')),
  otp_code_hash text,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  pending_user_id uuid,
  registration_payload jsonb,
  verification_method text,
  whatsapp_sender_phone text,
  metadata jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists otp_sessions_phone_status_idx
  on public.otp_sessions (phone_number, status, created_at desc);

create index if not exists otp_sessions_purpose_status_idx
  on public.otp_sessions (purpose, status, created_at desc);

create index if not exists otp_sessions_pending_user_idx
  on public.otp_sessions (pending_user_id)
  where pending_user_id is not null;

create unique index if not exists otp_sessions_pending_whatsapp_token_unique_idx
  on public.otp_sessions (otp_code_hash)
  where status = 'pending'
    and verification_method = 'whatsapp_inbound'
    and otp_code_hash is not null;

alter table if exists public.users
  add column if not exists phone_verified boolean not null default false;

alter table if exists public.users
  add column if not exists phone_verified_at timestamptz;

notify pgrst, 'reload schema';
