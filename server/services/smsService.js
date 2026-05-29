const { authConfig } = require('../config/authConfig');
const { getSmsProvider } = require('../config/startupChecks');
const { AppError } = require('../utils/appError');

const buildOtpMessage = ({ otpCode, purpose }) =>
  `GuardianNode ${purpose} code: ${otpCode}. It expires in ${authConfig.otpExpiresMinutes} minutes.`;

const parseProviderError = async (response) => {
  const rawBody = await response.text();

  try {
    const parsedBody = JSON.parse(rawBody);
    return parsedBody.message || parsedBody.error_message || rawBody;
  } catch (_) {
    return rawBody;
  }
};

const sendTwilioOtp = async ({ phoneNumber, otpCode, purpose }) => {
  if (typeof fetch !== 'function') {
    throw new AppError(
      'The current Node.js runtime does not support fetch. Use Node 18+ for Twilio SMS delivery.',
      500,
      'sms_runtime_unsupported'
    );
  }

  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const fromNumber = process.env.TWILIO_FROM_NUMBER;
  const missingValues = [
    ['TWILIO_ACCOUNT_SID', accountSid],
    ['TWILIO_AUTH_TOKEN', authToken],
    ['TWILIO_FROM_NUMBER', fromNumber],
  ]
    .filter(([, value]) => !String(value ?? '').trim())
    .map(([name]) => name);

  if (missingValues.length > 0) {
    throw new AppError(
      `Twilio SMS is not configured. Missing: ${missingValues.join(', ')}`,
      503,
      'sms_provider_not_configured'
    );
  }

  const requestBody = new URLSearchParams({
    To: phoneNumber,
    From: fromNumber,
    Body: buildOtpMessage({ otpCode, purpose }),
  });
  const credentials = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: requestBody.toString(),
    }
  );

  if (!response.ok) {
    const providerMessage = await parseProviderError(response);
    throw new AppError(
      'SMS provider could not deliver the OTP. Please try again.',
      502,
      'sms_provider_delivery_failed',
      {
        provider: 'twilio',
        status: response.status,
        message: providerMessage,
      }
    );
  }

  const payload = await response.json();
  return {
    delivered: true,
    provider: 'twilio',
    provider_message_id: payload.sid,
    phone_number: phoneNumber,
    purpose,
  };
};

const sendOtp = async (payload) => {
  const { phoneNumber, purpose } = payload;

  if (authConfig.debugAuthMode) {
    return {
      delivered: false,
      provider: 'debug',
      phone_number: phoneNumber,
      purpose,
    };
  }

  if (getSmsProvider() === 'twilio') {
    return sendTwilioOtp(payload);
  }

  throw new AppError(
    'Real SMS delivery is not configured. Set SMS_PROVIDER=twilio and provide Twilio credentials, or enable DEBUG_AUTH_MODE for local development only.',
    503,
    'sms_provider_not_configured'
  );
};

module.exports = {
  sendOtp,
};
