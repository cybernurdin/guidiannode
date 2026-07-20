const { authConfig, buildDebugOtpHelperMessage } = require('../config/authConfig');
const { OTP_PURPOSE, normalizeOtpPurpose } = require('../constants/otpPurpose');
const { AppError } = require('../utils/appError');
const otpService = require('./otpService');
const { createAppSession } = require('./sessionService');
const userService = require('./userService');
const whatsappVerificationService = require('./whatsappVerificationService');
const { normalizePhoneNumber, hashPassword, verifyPassword } = require('../utils/authUtils');

const verificationCompletionPromises = new Map();
const ACCOUNT_NOT_ALLOWED_STATUSES = new Set([
  'blocked',
  'disabled',
  'inactive',
  'rejected',
  'suspended',
]);

const assertAccountAllowed = (user) => {
  const accountStatus = String(user?.account_status ?? '').toLowerCase();

  if (ACCOUNT_NOT_ALLOWED_STATUSES.has(accountStatus)) {
    throw new AppError(
      'This account is not allowed to sign in. Please contact support.',
      403,
      'ACCOUNT_NOT_ALLOWED'
    );
  }
};

const buildOtpStartResponse = (otpSession, message) => ({
  success: true,
  message,
  otp_session_id: otpSession.id,
  phone_number: otpSession.phone_number,
  expires_at: otpSession.expires_at,
  next_step: 'verify_otp',
  otp_length: otpSession.metadata?.otp_length ?? authConfig.primaryOtpLength,
  auto_verify_ready: Boolean(otpSession.metadata?.auto_verify_ready),
  debug: otpSession.debug,
});

const startLoginOtp = async ({ phone_number }) => {
  const startTime = Date.now();
  const normalizedPhone = normalizePhoneNumber(phone_number);
  const existingUser = await userService.getUserByPhoneNumber(normalizedPhone);

  if (!existingUser) {
    throw new AppError(
      'This phone number is not registered. Please create an account first.',
      404,
      'PHONE_NOT_REGISTERED'
    );
  }

  assertAccountAllowed(existingUser);

  const verification = await whatsappVerificationService.createLoginVerification(
    normalizedPhone,
    existingUser.id
  );
  
  const duration = Date.now() - startTime;
  console.log(`[auth] startLoginOtp for ${normalizedPhone} completed in ${duration}ms`);

  return {
    ...buildWhatsappVerificationStartResponse(verification),
    message: 'Continue with WhatsApp to verify your login.',
  };
};

const startRegistrationOtp = async (registrationData) => {
  const normalizedPhone = normalizePhoneNumber(registrationData.phone_number);
  const existingUser = await userService.getUserByPhoneNumber(normalizedPhone);

  if (existingUser) {
    throw new AppError(
      'This phone number is already registered. Please login instead.',
      409,
      'PHONE_ALREADY_EXISTS'
    );
  }

  const normalizedData = {
    ...registrationData,
    phone_number: normalizedPhone,
  };
  const otpSession = await otpService.createOtpSession({
    phoneNumber: normalizedPhone,
    purpose: OTP_PURPOSE.REGISTER,
    registrationPayload: normalizedData,
  });

  return buildOtpStartResponse(
    otpSession,
    'Registration details accepted. Continue to OTP verification.'
  );
};

const buildWhatsappVerificationStartResponse = ({
  otpSession,
  token,
  expiresAt,
  whatsappUrl,
}) => ({
  success: true,
  message: 'Registration details accepted. Continue with WhatsApp verification.',
  verificationId: otpSession.id,
  purpose: normalizeOtpPurpose(otpSession.purpose),
  token,
  expiresAt,
  whatsappUrl,
  next_step: 'verify_whatsapp',
  // Compatibility alias for older clients that still name this record an OTP session.
  otp_session_id: otpSession.id,
  expires_at: expiresAt,
});

const startRegistrationWhatsappVerification = async (registrationData) => {
  const startTime = Date.now();
  const normalizedPhone = normalizePhoneNumber(registrationData.phone_number);

  const existingUser = await userService.getUserByPhoneNumber(normalizedPhone);
  if (existingUser) {
    throw new AppError(
      'This phone number is already registered. Please login instead.',
      409,
      'PHONE_ALREADY_EXISTS'
    );
  }

  const normalizedData = {
    ...registrationData,
    phone_number: normalizedPhone,
  };

  const verification = await whatsappVerificationService.createRegistrationVerification(
    normalizedData
  );

  const duration = Date.now() - startTime;
  console.log(`[REGISTER_START] completedMs=${duration}`);

  return buildWhatsappVerificationStartResponse(verification);
};

const buildSafeUserPayload = (user) => {
  if (!user || typeof user !== 'object') {
    return null;
  }

  const allowedFields = [
    'id',
    'full_name',
    'phone_number',
    'email',
    'quarter',
    'location_permission',
    'latitude',
    'longitude',
    'phone_verified',
    'phone_verified_at',
    'emergency_contact',
    'created_at',
    'updated_at',
  ];

  return allowedFields.reduce((payload, field) => {
    if (Object.prototype.hasOwnProperty.call(user, field)) {
      payload[field] = user[field];
    }
    return payload;
  }, {});
};

const buildAuthenticatedPayload = (user, emergencyContact, message) => {
  const enrichedUser = emergencyContact
    ? {
        ...user,
        emergency_contact: emergencyContact,
      }
    : user;
  const safeUser = buildSafeUserPayload(enrichedUser);

  const helperMessage = buildDebugOtpHelperMessage();

  return {
    success: true,
    message,
    session: createAppSession(safeUser),
    user: safeUser,
    redirect: '/dashboard',
    debug: helperMessage
      ? {
          mode: 'debug',
          helper_message: helperMessage,
        }
      : null,
  };
};

const finalizeRegistration = async (
  otpSession,
  { phoneAvailabilityChecked = false } = {}
) => {
  const registrationPayload = otpSession.registration_payload;

  if (!registrationPayload) {
    throw new AppError('Registration session is missing payload data.', 500, 'registration_payload_missing');
  }

  if (!phoneAvailabilityChecked) {
    const existingUser = await userService.getUserByPhoneNumber(
      otpSession.phone_number
    );
    if (existingUser) {
      throw new AppError(
        'This phone number is already registered. Please login instead.',
        409,
        'PHONE_ALREADY_EXISTS'
      );
    }
  }

  const userId = (
    await userService.ensureAuthUserForPhoneNumber({
      phoneNumber: otpSession.phone_number,
      fullName: registrationPayload.full_name,
    })
  ).id;

  const verifiedUser = await userService.saveNewVerifiedUserProfile({
    id: userId,
    full_name: registrationPayload.full_name,
    phone_number: otpSession.phone_number,
    quarter: registrationPayload.quarter,
    location_permission: registrationPayload.location_permission,
    latitude: registrationPayload.latitude ?? null,
    longitude: registrationPayload.longitude ?? null,
  });
  const emergencyContact = await userService.saveNewEmergencyContact({
    user_id: userId,
    contact_name: registrationPayload.emergency_contact.contact_name,
    phone_number: registrationPayload.emergency_contact.phone_number,
    relationship: registrationPayload.emergency_contact.relationship,
  });

  return buildAuthenticatedPayload(
    verifiedUser,
    emergencyContact,
    'Phone verified. Registration completed successfully.'
  );
};

const finalizeLogin = async (otpSession, existingUser = null) => {
  const user =
    existingUser ??
    (await userService.getUserByPhoneNumber(otpSession.phone_number));

  if (!user) {
    throw new AppError(
      'This phone number is not registered. Please create an account first.',
      404,
      'PHONE_NOT_REGISTERED'
    );
  }

  assertAccountAllowed(user);

  const [verifiedUser, emergencyContact] = await Promise.all([
    user.phone_verified === true
      ? user
      : userService.markUserPhoneVerified(user),
    userService.getPrimaryEmergencyContact(user.id),
  ]);

  return buildAuthenticatedPayload(
    verifiedUser,
    emergencyContact,
    'Phone verified successfully.'
  );
};

const getCompletedUserFromMetadata = (otpSession) => {
  const completedUser = otpSession?.metadata?.auth_completion?.user;

  if (!completedUser || typeof completedUser !== 'object' || !completedUser.id) {
    return null;
  }

  return completedUser;
};

const wasVerifiedBeforeExpiry = (otpSession) => {
  const expiresAt = new Date(otpSession.expires_at).getTime();
  const verifiedAt = new Date(otpSession.verified_at).getTime();

  if (!Number.isFinite(expiresAt)) {
    return true;
  }

  if (Number.isFinite(verifiedAt)) {
    return verifiedAt <= expiresAt;
  }

  return expiresAt > Date.now();
};

const completeVerifiedOtpSession = async (
  otpSession,
  {
    existingUser = null,
    registrationPhoneAvailabilityChecked = false,
    deferAuthCompletionPersistence = false,
  } = {}
) => {
  if (!otpSession || otpSession.status !== 'verified') {
    throw new AppError(
      'Verification is not ready to complete authentication.',
      409,
      'verification_not_verified'
    );
  }

  if (!wasVerifiedBeforeExpiry(otpSession)) {
    throw new AppError(
      'The verification was completed after it expired. Please request a new link.',
      410,
      'verification_expired'
    );
  }

  const completedUser = getCompletedUserFromMetadata(otpSession);
  if (completedUser) {
    return buildAuthenticatedPayload(
      completedUser,
      null,
      'WhatsApp verification complete.'
    );
  }

  const existingCompletion = verificationCompletionPromises.get(otpSession.id);
  if (existingCompletion) {
    return existingCompletion;
  }

  const completionPromise = (async () => {
    const otpPurpose = normalizeOtpPurpose(otpSession.purpose);

    if (otpPurpose === OTP_PURPOSE.REGISTER) {
      return finalizeRegistration(otpSession, {
        phoneAvailabilityChecked: registrationPhoneAvailabilityChecked,
      });
    }

    if (otpPurpose === OTP_PURPOSE.LOGIN) {
      return finalizeLogin(otpSession, existingUser);
    }

    throw new AppError(
      `Unsupported verification purpose: ${otpSession.purpose}`,
      500,
      'unsupported_verification_purpose'
    );
  })();

  verificationCompletionPromises.set(otpSession.id, completionPromise);

  try {
    const response = await completionPromise;
    const persistencePromise =
      whatsappVerificationService.saveVerificationAuthCompletion(
        otpSession,
        response.user
      );

    if (deferAuthCompletionPersistence) {
      const trackedCompletion = persistencePromise.then(() => response);
      verificationCompletionPromises.set(otpSession.id, trackedCompletion);
      void trackedCompletion
        .catch((error) => {
          console.error(
            `[auth] Failed to persist auth completion for verification ${otpSession.id}:`,
            error
          );
        })
        .finally(() => {
          if (
            verificationCompletionPromises.get(otpSession.id) ===
            trackedCompletion
          ) {
            verificationCompletionPromises.delete(otpSession.id);
          }
        });
      return response;
    }

    await persistencePromise;
    verificationCompletionPromises.delete(otpSession.id);
    return response;
  } catch (error) {
    verificationCompletionPromises.delete(otpSession.id);
    throw error;
  }
};

const isVerificationCompletionInProgress = (verificationId) =>
  verificationCompletionPromises.has(verificationId);

const getVerificationStatus = async ({ verificationId }) => {
  const startTime = Date.now();

  try {
    const otpSession = await whatsappVerificationService.resolveVerificationSessionStatus(
      verificationId
    );
    const status = otpSession.status;

    if (status === 'pending') {
      return {
        success: true,
        verificationId: otpSession.id,
        status: 'pending',
        verified: false,
        authReady: false,
        expiresAt: otpSession.expires_at,
      };
    }

    if (status === 'expired') {
      return {
        success: true,
        verificationId: otpSession.id,
        status: 'expired',
        verified: false,
        authReady: false,
        expiresAt: otpSession.expires_at,
        message: 'Your verification link has expired. Please request a new one.',
      };
    }

    if (status !== 'verified') {
      return {
        success: true,
        verificationId: otpSession.id,
        status,
        verified: false,
        authReady: false,
        expiresAt: otpSession.expires_at,
      };
    }

    if (!wasVerifiedBeforeExpiry(otpSession)) {
      return {
        success: true,
        verificationId: otpSession.id,
        status: 'expired',
        verified: false,
        authReady: false,
        expiresAt: otpSession.expires_at,
        message: 'Your verification link expired before authentication completed.',
      };
    }

    if (
      !getCompletedUserFromMetadata(otpSession) &&
      isVerificationCompletionInProgress(otpSession.id)
    ) {
      return {
        success: true,
        verificationId: otpSession.id,
        status: 'verified',
        verified: true,
        authReady: false,
        expiresAt: otpSession.expires_at,
        nextStep: 'completing_auth',
        message: 'WhatsApp verified. Finishing secure sign-in.',
      };
    }

    const response = await completeVerifiedOtpSession(otpSession);

    return {
      success: true,
      verificationId: otpSession.id,
      status: 'verified',
      verified: true,
      authReady: true,
      expiresAt: otpSession.expires_at,
      user: response.user,
      session: response.session,
      authToken: response.session?.access_token,
      nextStep: 'dashboard',
      message: response.message || 'WhatsApp verification complete.',
    };
  } finally {
    console.log(
      `[VERIFICATION_STATUS] verificationId=${verificationId} completedMs=${Date.now() - startTime}`
    );
  }
};

const verifyOtp = async ({ phone_number, otp_code, otp_session_id }) => {
  const otpSession = await otpService.verifyOtpSession({
    phoneNumber: phone_number,
    otpCode: otp_code,
    otpSessionId: otp_session_id,
  });
  const otpPurpose = normalizeOtpPurpose(otpSession.purpose);

  try {
    if (otpPurpose === OTP_PURPOSE.REGISTER) {
      return await finalizeRegistration(otpSession);
    }

    if (otpPurpose === OTP_PURPOSE.LOGIN) {
      return await finalizeLogin(otpSession);
    }

    throw new AppError(
      `Unsupported OTP purpose: ${otpSession.purpose}`,
      500,
      'unsupported_otp_purpose'
    );
  } catch (errorToThrow) {
    try {
      await otpService.rollbackVerifiedOtpSession(otpSession);
    } catch (rollbackError) {
      console.error('OTP session rollback failed after post-verification error:', rollbackError);
    }

    throw errorToThrow;
  }
};

const resendOtp = async ({ phone_number, otp_session_id }) => {
  const otpSession = await otpService.resendOtpSession({
    phoneNumber: phone_number,
    otpSessionId: otp_session_id,
  });

  return buildOtpStartResponse(otpSession, 'OTP resent successfully');
};

const confirmWhatsappClick = async ({
  verificationId,
  otp_session_id,
  phone_number,
}) => {
  const startTime = Date.now();
  const sessionId = verificationId || otp_session_id;
  if (!sessionId) {
    throw new AppError('Verification session ID is required.', 400, 'validation_error');
  }

  const normalizedPhone = normalizePhoneNumber(phone_number);
  const [otpSession, matchedUser] = await Promise.all([
    whatsappVerificationService.resolveVerificationSessionStatus(sessionId),
    userService.getUserByPhoneNumber(normalizedPhone),
  ]);
  const otpPurpose = normalizeOtpPurpose(otpSession.purpose);
  const sessionNormalizedPhone = normalizePhoneNumber(otpSession.phone_number);

  if (normalizedPhone !== sessionNormalizedPhone) {
    throw new AppError('Phone number does not match the verification session.', 400, 'phone_mismatch');
  }

  if (!['pending', 'verified'].includes(otpSession.status)) {
    throw new AppError(
      'This verification session can no longer be confirmed.',
      409,
      'verification_not_pending'
    );
  }

  let existingUser = null;
  const completedUser = getCompletedUserFromMetadata(otpSession);
  const completionInProgress = isVerificationCompletionInProgress(otpSession.id);
  let authResponse = null;

  if (!completedUser && !completionInProgress && otpPurpose === OTP_PURPOSE.LOGIN) {
    existingUser = matchedUser;
    if (!existingUser) {
      throw new AppError(
        'This phone number is not registered. Please create an account first.',
        404,
        'PHONE_NOT_REGISTERED'
      );
    }
    assertAccountAllowed(existingUser);
  }

  if (
    !completedUser &&
    !completionInProgress &&
    otpPurpose === OTP_PURPOSE.REGISTER
  ) {
    if (matchedUser) {
      throw new AppError(
        'This phone number is already registered. Please login instead.',
        409,
        'PHONE_ALREADY_EXISTS'
      );
    }
  }

  const confirmedSession = completedUser || completionInProgress
    ? otpSession
    : await whatsappVerificationService.confirmWhatsappVerificationSession(
        otpSession
      );
  authResponse = await completeVerifiedOtpSession(confirmedSession, {
    existingUser,
    registrationPhoneAvailabilityChecked:
      !completedUser && otpPurpose === OTP_PURPOSE.REGISTER,
    deferAuthCompletionPersistence: true,
  });

  const response = {
    success: true,
    verificationId: confirmedSession.id,
    status: 'verified',
    verified: true,
    authReady: true,
    purpose: otpPurpose === OTP_PURPOSE.LOGIN ? 'login' : 'register',
    authToken: authResponse.session.access_token,
    session: authResponse.session,
    user: authResponse.user,
    nextStep: 'dashboard',
  };

  console.log(
    `[CONFIRM_WHATSAPP_CLICK] verificationId=${confirmedSession.id} purpose=${response.purpose} completedMs=${Date.now() - startTime}`
  );

  return response;
};

// --- Password-based sign-in (demo/competition path, alongside WhatsApp) ---
// Kept intentionally simple: no separate OTP/email-confirmation step. A
// password is proof of ownership by itself, so this does not weaken
// security the way phone-only login does.

const loginWithPassword = async ({ identifier, password }) => {
  const trimmedIdentifier = String(identifier ?? '').trim();
  const looksLikeEmail = trimmedIdentifier.includes('@');

  const user = looksLikeEmail
    ? await userService.getUserByEmail(trimmedIdentifier)
    : await userService.getUserByPhoneNumber(trimmedIdentifier);

  if (!user || !user.password_hash) {
    throw new AppError(
      'No account with that phone number or email has a password set. Register with a password first.',
      404,
      'PASSWORD_ACCOUNT_NOT_FOUND'
    );
  }

  assertAccountAllowed(user);

  if (!verifyPassword(password, user.password_hash)) {
    throw new AppError('Incorrect password.', 401, 'INVALID_PASSWORD');
  }

  const emergencyContact = await userService.getPrimaryEmergencyContact(user.id);

  return buildAuthenticatedPayload(user, emergencyContact, 'Signed in successfully.');
};

const registerWithPassword = async ({
  full_name,
  phone_number,
  email,
  password,
  quarter,
  location_permission,
  latitude,
  longitude,
}) => {
  const normalizedPhone = normalizePhoneNumber(phone_number);
  const [existingByPhone, existingByEmail] = await Promise.all([
    userService.getUserByPhoneNumber(normalizedPhone),
    email ? userService.getUserByEmail(email) : Promise.resolve(null),
  ]);

  if (existingByPhone) {
    if (!existingByPhone.password_hash) {
      const passwordHash = hashPassword(password);
      const updatedUser = await userService.setUserPassword({
        userId: existingByPhone.id,
        passwordHash,
      });
      const emergencyContact = await userService.getPrimaryEmergencyContact(
        existingByPhone.id
      );
      return buildAuthenticatedPayload(
        updatedUser,
        emergencyContact,
        'Password set for your existing account. Signed in successfully.'
      );
    }

    throw new AppError(
      'This phone number is already registered. Please login instead.',
      409,
      'PHONE_ALREADY_EXISTS'
    );
  }

  if (existingByEmail) {
    throw new AppError(
      'This email is already registered. Please login instead.',
      409,
      'EMAIL_ALREADY_EXISTS'
    );
  }

  const passwordHash = hashPassword(password);
  const authUser = await userService.ensureAuthUserForPhoneNumber({
    phoneNumber: normalizedPhone,
    fullName: full_name,
  });

  const newUser = await userService.createUserWithPassword({
    id: authUser.id,
    full_name,
    phone_number: normalizedPhone,
    email,
    password_hash: passwordHash,
    quarter,
    location_permission,
    latitude,
    longitude,
  });

  return buildAuthenticatedPayload(
    newUser,
    null,
    'Account created successfully.'
  );
};

// Demo/competition-only shortcut: signs in with just a registered phone
// number, no password or OTP. This intentionally trades verification for
// speed -- do not enable this path for a real public deployment.
const loginWithPhoneOnly = async ({ phone_number }) => {
  const normalizedPhone = normalizePhoneNumber(phone_number);
  const user = await userService.getUserByPhoneNumber(normalizedPhone);

  if (!user) {
    throw new AppError(
      'This phone number is not registered. Please create an account first.',
      404,
      'PHONE_NOT_REGISTERED'
    );
  }

  assertAccountAllowed(user);

  const emergencyContact = await userService.getPrimaryEmergencyContact(user.id);

  return buildAuthenticatedPayload(user, emergencyContact, 'Signed in successfully.');
};

module.exports = {
  completeVerifiedOtpSession,
  confirmWhatsappClick,
  getVerificationStatus,
  isVerificationCompletionInProgress,
  loginWithPassword,
  loginWithPhoneOnly,
  registerWithPassword,
  resendOtp,
  startLoginOtp,
  startRegistrationOtp,
  startRegistrationWhatsappVerification,
  verifyOtp,
};
