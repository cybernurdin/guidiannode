alter table if exists public.otp_sessions
  add column if not exists pending_user_id uuid;

alter table if exists public.otp_sessions
  add column if not exists verification_method text;

alter table if exists public.otp_sessions
  add column if not exists whatsapp_sender_phone text;

alter table if exists public.users
  add column if not exists phone_verified boolean not null default false;

alter table if exists public.users
  add column if not exists phone_verified_at timestamptz;

create index if not exists otp_sessions_whatsapp_sender_phone_idx
  on public.otp_sessions (whatsapp_sender_phone)
  where whatsapp_sender_phone is not null;

create index if not exists otp_sessions_pending_user_idx
  on public.otp_sessions (pending_user_id)
  where pending_user_id is not null;

notify pgrst, 'reload schema';
