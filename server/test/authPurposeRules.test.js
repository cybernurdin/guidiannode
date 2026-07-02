const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'test_jwt_secret_with_enough_length_for_unit_tests';

const authServicePath = require.resolve('../services/authService');
const dependencyPaths = {
  otpService: require.resolve('../services/otpService'),
  sessionService: require.resolve('../services/sessionService'),
  userService: require.resolve('../services/userService'),
  whatsappVerificationService: require.resolve(
    '../services/whatsappVerificationService'
  ),
};

const buildSession = (user) => ({
  access_token: 'test-access-token',
  token_type: 'Bearer',
  expires_at: new Date(Date.now() + 60_000).toISOString(),
  user,
});

const loadAuthService = ({
  userService = {},
  whatsappVerificationService = {},
} = {}) => {
  const originalEntries = new Map();
  const rememberAndMock = (path, exports) => {
    originalEntries.set(path, require.cache[path]);
    require.cache[path] = {
      id: path,
      filename: path,
      loaded: true,
      exports,
      children: [],
      paths: [],
    };
  };

  const defaultUserService = {
    ensureAuthUserForPhoneNumber: async () => ({
      id: 'new-auth-user-id',
    }),
    getPrimaryEmergencyContact: async () => null,
    getUserByPhoneNumber: async () => null,
    markUserPhoneVerified: async (user) => ({
      ...user,
      account_status: 'active',
      phone_verified: true,
    }),
    saveEmergencyContact: async (contact) => ({
      id: 'contact-id',
      ...contact,
    }),
    saveNewEmergencyContact: async (contact) => ({
      id: 'contact-id',
      ...contact,
    }),
    saveNewVerifiedUserProfile: async (user) => ({
      ...user,
      account_status: 'active',
      phone_verified: true,
    }),
    saveUserProfile: async (user) => user,
    ...userService,
  };
  const defaultWhatsappService = {
    confirmWhatsappVerificationSession: async (session) => ({
      ...session,
      status: 'verified',
      verified_at: new Date().toISOString(),
    }),
    createLoginVerification: async (phoneNumber, userId) => ({
      otpSession: {
        id: 'login-verification-id',
        phone_number: phoneNumber,
        pending_user_id: userId,
        purpose: 'login',
        expires_at: new Date(Date.now() + 60_000).toISOString(),
      },
      token: 'CM-LOGIN',
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
      whatsappUrl: 'https://wa.me/237657262038?text=CM-LOGIN',
    }),
    createRegistrationVerification: async (registrationData) => ({
      otpSession: {
        id: 'register-verification-id',
        phone_number: registrationData.phone_number,
        purpose: 'register',
        registration_payload: registrationData,
        expires_at: new Date(Date.now() + 60_000).toISOString(),
      },
      token: 'CM-REGIS',
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
      whatsappUrl: 'https://wa.me/237657262038?text=CM-REGIS',
    }),
    resolveVerificationSessionStatus: async () => null,
    saveVerificationAuthCompletion: async () => null,
    ...whatsappVerificationService,
  };

  rememberAndMock(dependencyPaths.otpService, {});
  rememberAndMock(dependencyPaths.sessionService, {
    createAppSession: buildSession,
  });
  rememberAndMock(dependencyPaths.userService, defaultUserService);
  rememberAndMock(
    dependencyPaths.whatsappVerificationService,
    defaultWhatsappService
  );

  delete require.cache[authServicePath];
  const authService = require(authServicePath);

  const cleanup = () => {
    delete require.cache[authServicePath];
    for (const [path, originalEntry] of originalEntries.entries()) {
      if (originalEntry) {
        require.cache[path] = originalEntry;
      } else {
        delete require.cache[path];
      }
    }
  };

  return { authService, cleanup };
};

test('login rejects an unregistered phone without creating a session or user', async (t) => {
  let verificationCreated = false;
  let authUserCreated = false;
  const { authService, cleanup } = loadAuthService({
    userService: {
      ensureAuthUserForPhoneNumber: async () => {
        authUserCreated = true;
      },
      getUserByPhoneNumber: async () => null,
    },
    whatsappVerificationService: {
      createLoginVerification: async () => {
        verificationCreated = true;
      },
    },
  });
  t.after(cleanup);

  await assert.rejects(
    authService.startLoginOtp({ phone_number: '677034736' }),
    (error) => error.code === 'PHONE_NOT_REGISTERED'
  );
  assert.equal(verificationCreated, false);
  assert.equal(authUserCreated, false);
});

test('login for an existing allowed user creates a login verification', async (t) => {
  const existingUser = {
    id: 'existing-user-id',
    phone_number: '237677034736',
    account_status: 'active',
  };
  let receivedPhone;
  let receivedUserId;
  const { authService, cleanup } = loadAuthService({
    userService: {
      getUserByPhoneNumber: async () => existingUser,
    },
    whatsappVerificationService: {
      createLoginVerification: async (phoneNumber, userId) => {
        receivedPhone = phoneNumber;
        receivedUserId = userId;
        return {
          otpSession: {
            id: 'login-verification-id',
            phone_number: phoneNumber,
            purpose: 'login',
            expires_at: new Date(Date.now() + 60_000).toISOString(),
          },
          token: 'CM-LOGIN',
          expiresAt: new Date(Date.now() + 60_000).toISOString(),
          whatsappUrl: 'https://wa.me/237657262038?text=CM-LOGIN',
        };
      },
    },
  });
  t.after(cleanup);

  const response = await authService.startLoginOtp({
    phone_number: '+237 6 77 03 47 36',
  });

  assert.equal(receivedPhone, '237677034736');
  assert.equal(receivedUserId, existingUser.id);
  assert.equal(response.purpose, 'login');
});

test('login rejects an existing blocked account', async (t) => {
  let verificationCreated = false;
  const { authService, cleanup } = loadAuthService({
    userService: {
      getUserByPhoneNumber: async () => ({
        id: 'blocked-user-id',
        phone_number: '237677034736',
        account_status: 'blocked',
      }),
    },
    whatsappVerificationService: {
      createLoginVerification: async () => {
        verificationCreated = true;
      },
    },
  });
  t.after(cleanup);

  await assert.rejects(
    authService.startLoginOtp({ phone_number: '237677034736' }),
    (error) => error.code === 'ACCOUNT_NOT_ALLOWED'
  );
  assert.equal(verificationCreated, false);
});

test('registration rejects an existing phone before creating a verification', async (t) => {
  let verificationCreated = false;
  const { authService, cleanup } = loadAuthService({
    userService: {
      getUserByPhoneNumber: async () => ({
        id: 'existing-user-id',
        phone_number: '237677034736',
      }),
    },
    whatsappVerificationService: {
      createRegistrationVerification: async () => {
        verificationCreated = true;
      },
    },
  });
  t.after(cleanup);

  await assert.rejects(
    authService.startRegistrationWhatsappVerification({
      phone_number: '677034736',
    }),
    (error) => error.code === 'PHONE_ALREADY_EXISTS'
  );
  assert.equal(verificationCreated, false);
});

test('registration for a new phone creates a normalized register verification', async (t) => {
  let registrationPayload;
  const { authService, cleanup } = loadAuthService({
    whatsappVerificationService: {
      createRegistrationVerification: async (payload) => {
        registrationPayload = payload;
        return {
          otpSession: {
            id: 'register-verification-id',
            phone_number: payload.phone_number,
            purpose: 'register',
            expires_at: new Date(Date.now() + 60_000).toISOString(),
          },
          token: 'CM-REGIS',
          expiresAt: new Date(Date.now() + 60_000).toISOString(),
          whatsappUrl: 'https://wa.me/237657262038?text=CM-REGIS',
        };
      },
    },
  });
  t.after(cleanup);

  const response = await authService.startRegistrationWhatsappVerification({
    full_name: 'Test User',
    phone_number: '+237 6 77 03 47 36',
  });

  assert.equal(registrationPayload.phone_number, '237677034736');
  assert.equal(response.purpose, 'register');
});

test('confirm click authenticates an existing login user without creating a user', async (t) => {
  let authUserCreated = false;
  const existingUser = {
    id: 'existing-user-id',
    full_name: 'Existing User',
    phone_number: '237677034736',
    account_status: 'active',
  };
  const pendingSession = {
    id: 'login-verification-id',
    phone_number: '237677034736',
    purpose: 'login',
    status: 'pending',
    expires_at: new Date(Date.now() + 60_000).toISOString(),
    metadata: {},
  };
  const { authService, cleanup } = loadAuthService({
    userService: {
      ensureAuthUserForPhoneNumber: async () => {
        authUserCreated = true;
      },
      getUserByPhoneNumber: async () => existingUser,
    },
    whatsappVerificationService: {
      resolveVerificationSessionStatus: async () => pendingSession,
    },
  });
  t.after(cleanup);

  const response = await authService.confirmWhatsappClick({
    verificationId: pendingSession.id,
    phone_number: '677034736',
  });

  assert.equal(response.success, true);
  assert.equal(response.purpose, 'login');
  assert.equal(response.authToken, 'test-access-token');
  assert.equal(response.session.user.id, existingUser.id);
  assert.equal(response.nextStep, 'dashboard');
  assert.equal(authUserCreated, false);
});

test('confirm click completes registration for a new phone and returns a session', async (t) => {
  const pendingSession = {
    id: 'register-verification-id',
    phone_number: '237677034736',
    purpose: 'register',
    status: 'pending',
    expires_at: new Date(Date.now() + 60_000).toISOString(),
    registration_payload: {
      full_name: 'New User',
      phone_number: '237677034736',
      quarter: 'Bamenda',
      location_permission: false,
      emergency_contact: {
        contact_name: 'Trusted Contact',
        phone_number: '237688888888',
        relationship: 'Friend',
      },
    },
    metadata: {},
  };
  const { authService, cleanup } = loadAuthService({
    whatsappVerificationService: {
      resolveVerificationSessionStatus: async () => pendingSession,
    },
  });
  t.after(cleanup);

  const response = await authService.confirmWhatsappClick({
    verificationId: pendingSession.id,
    phone_number: '+237677034736',
  });

  assert.equal(response.success, true);
  assert.equal(response.purpose, 'register');
  assert.equal(response.authToken, 'test-access-token');
  assert.equal(response.user.phone_verified, true);
  assert.equal(response.nextStep, 'dashboard');
});

test('confirm click rejects registration when the phone now belongs to a user', async (t) => {
  const pendingSession = {
    id: 'register-verification-id',
    phone_number: '237677034736',
    purpose: 'register',
    status: 'pending',
    expires_at: new Date(Date.now() + 60_000).toISOString(),
    registration_payload: {},
    metadata: {},
  };
  const { authService, cleanup } = loadAuthService({
    userService: {
      getUserByPhoneNumber: async () => ({
        id: 'existing-user-id',
        phone_number: '237677034736',
      }),
    },
    whatsappVerificationService: {
      resolveVerificationSessionStatus: async () => pendingSession,
    },
  });
  t.after(cleanup);

  await assert.rejects(
    authService.confirmWhatsappClick({
      verificationId: pendingSession.id,
      phone_number: '237677034736',
    }),
    (error) => error.code === 'PHONE_ALREADY_EXISTS'
  );
});

test('completed registration confirmation is idempotent', async (t) => {
  const completedUser = {
    id: 'registered-user-id',
    full_name: 'Registered User',
    phone_number: '237677034736',
    phone_verified: true,
  };
  const verifiedSession = {
    id: 'register-verification-id',
    phone_number: '237677034736',
    purpose: 'register',
    status: 'verified',
    verified_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 60_000).toISOString(),
    metadata: {
      auth_completion: {
        user: completedUser,
      },
    },
  };
  const { authService, cleanup } = loadAuthService({
    userService: {
      getUserByPhoneNumber: async () => completedUser,
    },
    whatsappVerificationService: {
      resolveVerificationSessionStatus: async () => verifiedSession,
    },
  });
  t.after(cleanup);

  const response = await authService.confirmWhatsappClick({
    verificationId: verifiedSession.id,
    phone_number: '677034736',
  });

  assert.equal(response.success, true);
  assert.equal(response.purpose, 'register');
  assert.equal(response.user.id, completedUser.id);
  assert.equal(response.authToken, 'test-access-token');
});
