const { supabaseAdmin } = require('./supabaseClient');

const checkDatabaseReadiness = async () => {
  const [otpSessionsResult, usersResult] = await Promise.all([
    supabaseAdmin
      .from('otp_sessions')
      .select(
        'id, pending_user_id, phone_number, status, expires_at, verified_at, verification_method, whatsapp_sender_phone'
      )
      .limit(1),
    supabaseAdmin
      .from('users')
      .select('id, phone_verified, phone_verified_at')
      .limit(1),
  ]);

  return {
    ok: !otpSessionsResult.error && !usersResult.error,
    checks: {
      otp_sessions_whatsapp_schema: !otpSessionsResult.error,
      users_phone_verification_schema: !usersResult.error,
    },
  };
};

module.exports = {
  checkDatabaseReadiness,
};
