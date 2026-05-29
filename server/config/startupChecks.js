const { authConfig } = require('./authConfig');

const REQUIRED_BACKEND_ENV = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'JWT_SECRET',
  'GOOGLE_MAPS_SERVER_API_KEY',
];

const TWILIO_ENV = [
  'TWILIO_ACCOUNT_SID',
  'TWILIO_AUTH_TOKEN',
  'TWILIO_FROM_NUMBER',
];

const getMissingEnv = (names) =>
  names.filter((name) => !String(process.env[name] ?? '').trim());

const getSmsProvider = () =>
  String(process.env.SMS_PROVIDER || '').trim().toLowerCase() || 'none';

const assertProductionReady = () => {
  const missingBackendEnv = getMissingEnv(REQUIRED_BACKEND_ENV);

  if (missingBackendEnv.length > 0) {
    throw new Error(
      `Missing required backend environment variables: ${missingBackendEnv.join(', ')}`
    );
  }

  if (process.env.NODE_ENV !== 'production') {
    return;
  }

  if (authConfig.debugAuthMode) {
    throw new Error('DEBUG_AUTH_MODE must be false when NODE_ENV=production.');
  }

  const smsProvider = getSmsProvider();
  if (smsProvider !== 'twilio') {
    throw new Error(
      'SMS_PROVIDER=twilio is required in production so OTP delivery can work.'
    );
  }

  const missingTwilioEnv = getMissingEnv(TWILIO_ENV);
  if (missingTwilioEnv.length > 0) {
    throw new Error(
      `Missing Twilio environment variables: ${missingTwilioEnv.join(', ')}`
    );
  }
};

const buildReadinessSnapshot = () => ({
  service: 'GuardianNode API',
  environment: process.env.NODE_ENV || 'development',
  auth_mode: authConfig.debugAuthMode ? 'debug' : 'otp_sms',
  sms_provider: authConfig.debugAuthMode ? 'debug' : getSmsProvider(),
  checks: {
    supabase_url: Boolean(process.env.SUPABASE_URL),
    supabase_service_role_key: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
    google_maps_server_api_key: Boolean(process.env.GOOGLE_MAPS_SERVER_API_KEY),
    jwt_secret: Boolean(process.env.JWT_SECRET),
    cors_origin: Boolean(process.env.CORS_ORIGIN || process.env.CLIENT_ORIGIN),
  },
});

module.exports = {
  assertProductionReady,
  buildReadinessSnapshot,
  getSmsProvider,
};
