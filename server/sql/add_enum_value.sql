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

alter type public.otp_purpose_enum add value if not exists 'register';
alter type public.otp_purpose_enum add value if not exists 'login';
alter type public.otp_purpose_enum add value if not exists 'reset_password';
alter type public.otp_purpose_enum add value if not exists 'verify_phone';

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'otp_sessions'
      and column_name = 'purpose'
      and udt_name <> 'otp_purpose_enum'
  ) then
    alter table public.otp_sessions
      alter column purpose type public.otp_purpose_enum
      using (
        case purpose::text
          when 'registration' then 'register'
          else purpose::text
        end
      )::public.otp_purpose_enum;
  end if;
end $$;

alter table if exists public.otp_sessions
  add column if not exists attempts integer not null default 0;

alter table if exists public.otp_sessions
  add column if not exists max_attempts integer not null default 5;

alter table if exists public.otp_sessions
  add column if not exists registration_payload jsonb;

alter table if exists public.otp_sessions
  add column if not exists pending_user_id uuid;

alter table if exists public.otp_sessions
  add column if not exists verification_method text;

alter table if exists public.otp_sessions
  add column if not exists whatsapp_sender_phone text;

alter table if exists public.otp_sessions
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table if exists public.otp_sessions
  add column if not exists verified_at timestamptz;

alter table if exists public.otp_sessions
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.otp_sessions
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table if exists public.alerts
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table if exists public.users
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.users
  add column if not exists phone_verified boolean not null default false;

alter table if exists public.users
  add column if not exists phone_verified_at timestamptz;

alter table if exists public.emergency_contacts
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.incident_logs
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.notifications
  add column if not exists created_at timestamptz not null default timezone('utc', now());

create index if not exists otp_sessions_phone_status_idx
  on public.otp_sessions (phone_number, status, created_at desc);

create index if not exists otp_sessions_purpose_status_idx
  on public.otp_sessions (purpose, status, created_at desc);

create index if not exists otp_sessions_pending_user_idx
  on public.otp_sessions (pending_user_id)
  where pending_user_id is not null;

notify pgrst, 'reload schema';
