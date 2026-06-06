create index if not exists otp_sessions_whatsapp_token_status_idx
  on public.otp_sessions (otp_code_hash, status, expires_at)
  where otp_code_hash is not null;

create unique index if not exists otp_sessions_pending_whatsapp_token_unique_idx
  on public.otp_sessions (otp_code_hash)
  where status = 'pending'
    and verification_method = 'whatsapp_inbound'
    and otp_code_hash is not null;

notify pgrst, 'reload schema';
