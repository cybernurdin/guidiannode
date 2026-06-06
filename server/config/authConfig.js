require('dotenv').config();

const TRUE_VALUES = new Set(['1', 'true', 'yes', 'on']);
const FALSE_VALUES = new Set(['0', 'false', 'no', 'off']);
const REAL_OTP_LENGTH = 6;

const parseBoolean = (value, defaultValue = false) => {
  if (value === undefined || value === null || value === '') {
    return defaultValue;
  }

  const normalizedValue = String(value).trim().toLowerCase();

  if (TRUE_VALUES.has(normalizedValue)) {
    return true;
  }

  if (FALSE_VALUES.has(normalizedValue)) {
    return false;
  }

  return defaultValue;
};

const parseInteger = (value, defaultValue) => {
  const parsedValue = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsedValue) ? parsedValue : defaultValue;
};

const debugAuthMode = parseBoolean(process.env.DEBUG_AUTH_MODE, false);
const autoVerifyDebugOtp = parseBoolean(process.env.AUTO_VERIFY_DEBUG_OTP, false);
const debugDefaultOtp = (process.env.DEBUG_DEFAULT_OTP || '1234567').trim();
const debugBackupOtp = (process.env.DEBUG_BACKUP_OTP || '0000000').trim();
const debugOtpValues = [...new Set([debugDefaultOtp, debugBackupOtp].filter(Boolean))];
const debugOtpLengths = [...new Set(debugOtpValues.map((value) => value.length).filter(Boolean))];
const allowedOtpLengths = debugAuthMode
  ? [...new Set([REAL_OTP_LENGTH, ...debugOtpLengths])]
  : [REAL_OTP_LENGTH];

const authConfig = Object.freeze({
  debugAuthMode,
  autoVerifyDebugOtp,
  realOtpLength: REAL_OTP_LENGTH,
  debugDefaultOtp,
  debugBackupOtp,
  debugOtpValues,
  debugOtpLengths,
  allowedOtpLengths,
  primaryOtpLength: debugAuthMode ? debugDefaultOtp.length : REAL_OTP_LENGTH,
  debugOtpReferences: ['env:DEBUG_DEFAULT_OTP', 'env:DEBUG_BACKUP_OTP'],
  otpExpiresMinutes: parseInteger(process.env.OTP_EXPIRES_MINUTES, 10),
  maxOtpAttempts: 5,
  jwtSecret: process.env.JWT_SECRET || process.env.SESSION_SECRET,
  jwtExpiresIn: '7d',
  sessionExpiresInSeconds: 60 * 60 * 24 * 7,
});

if (!authConfig.jwtSecret) {
  throw new Error('Missing JWT_SECRET or SESSION_SECRET in environment variables');
}

const buildDebugOtpHelperMessage = () => {
  if (!authConfig.debugAuthMode) {
    return null;
  }

  return `Debug OTP mode enabled. Use code ${authConfig.debugDefaultOtp}.`;
};

const logAuthModeBanner = () => {
  if (!authConfig.debugAuthMode) {
    console.log('[auth] DEBUG_AUTH_MODE=false. Inbound WhatsApp verification is active.');
    return;
  }

  console.warn('[auth] WARNING: DEBUG_AUTH_MODE=true. Inbound WhatsApp verification is bypassed.');

  if (process.env.NODE_ENV === 'production') {
    console.warn('[auth] WARNING: Debug auth mode is active while NODE_ENV=production.');
  }

  if (authConfig.autoVerifyDebugOtp) {
    console.warn('[auth] AUTO_VERIFY_DEBUG_OTP=true. Newly created debug sessions are immediately verification-ready.');
  }
};

module.exports = {
  authConfig,
  buildDebugOtpHelperMessage,
  logAuthModeBanner,
  parseBoolean,
};
