const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { normalizePhoneNumber } = require('../utils/authUtils');

const args = process.argv.slice(2);

const readArg = (name, fallback = undefined) => {
  const index = args.findIndex((arg) => arg === name || arg.startsWith(`${name}=`));
  if (index < 0) {
    return fallback;
  }

  const arg = args[index];
  return arg.includes('=') ? arg.slice(arg.indexOf('=') + 1) : args[index + 1];
};

const baseUrl = String(
  readArg('--base-url', process.env.API_BASE_URL || 'http://localhost:3000')
).replace(/\/+$/, '');
const phoneNumber = readArg('--phone');
const contactPhone = readArg(
  '--contact-phone',
  process.env.WHATSAPP_TARGET_NUMBER || process.env.WHATSAPP_BUSINESS_NUMBER
);

const fail = (message, details = null) => {
  console.error(`[auth-purpose-flow] ${message}`);
  if (details) {
    console.error(JSON.stringify(details, null, 2));
  }
  console.log('FAIL');
  process.exit(1);
};

if (!phoneNumber || !contactPhone) {
  fail('Provide --phone and --contact-phone (or configure a WhatsApp target number).');
}

const parseResponse = async (response) => {
  const raw = await response.text();

  try {
    return raw ? JSON.parse(raw) : {};
  } catch {
    return { raw };
  }
};

const request = async (url, options = {}) => {
  const startedAt = performance.now();
  const response = await fetch(url, options);

  return {
    response,
    data: await parseResponse(response),
    elapsedMs: Math.round(performance.now() - startedAt),
  };
};

const postJson = (pathName, body, headers = {}) =>
  request(`${baseUrl}${pathName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });

const startLogin = () =>
  postJson('/api/auth/login/start-verification', {
    phone_number: phoneNumber,
  });

const startRegistration = () =>
  postJson('/api/auth/register/start-verification', {
    full_name: 'GuardianNode Purpose Test',
    phone_number: phoneNumber,
    quarter: 'Automated Test Quarter',
    location_permission: false,
    emergency_contact: {
      contact_name: 'GuardianNode Test Contact',
      phone_number: contactPhone,
      relationship: 'Friend',
    },
  });

const confirm = (verificationId) =>
  postJson('/api/verification/confirm-whatsapp-click', {
    verificationId,
    phone_number: phoneNumber,
  });

const assertAuthenticated = (result, expectedPurpose, label) => {
  const data = result.data;
  const token = data?.authToken || data?.session?.access_token;

  if (
    !result.response.ok ||
    data?.success !== true ||
    data?.status !== 'verified' ||
    data?.purpose !== expectedPurpose ||
    !token ||
    !data?.user?.id
  ) {
    fail(`${label} did not return an authenticated ${expectedPurpose} session.`, data);
  }

  return token;
};

const main = async () => {
  const flowStartedAt = performance.now();
  const normalizedPhone = normalizePhoneNumber(phoneNumber);

  console.log(`[auth-purpose-flow] normalizedPhone=${normalizedPhone}`);

  const missingLogin = await startLogin();
  console.log(
    `[auth-purpose-flow] missingLoginMs=${missingLogin.elapsedMs} code=${missingLogin.data?.code}`
  );

  if (
    missingLogin.response.status !== 404 ||
    missingLogin.data?.code !== 'PHONE_NOT_REGISTERED' ||
    missingLogin.data?.authToken ||
    missingLogin.data?.session
  ) {
    fail('Unknown login was not rejected safely.', missingLogin.data);
  }

  const registrationStart = await startRegistration();
  console.log(
    `[auth-purpose-flow] registrationStartMs=${registrationStart.elapsedMs} purpose=${registrationStart.data?.purpose}`
  );

  if (
    !registrationStart.response.ok ||
    registrationStart.data?.success !== true ||
    registrationStart.data?.purpose !== 'register' ||
    !registrationStart.data?.verificationId
  ) {
    fail(
      'Registration did not start after the unknown login check. Login may have created a user.',
      registrationStart.data
    );
  }

  const registrationConfirm = await confirm(registrationStart.data.verificationId);
  console.log(
    `[auth-purpose-flow] registrationConfirmMs=${registrationConfirm.elapsedMs}`
  );
  assertAuthenticated(registrationConfirm, 'register', 'Registration confirmation');

  const registrationRetry = await confirm(registrationStart.data.verificationId);
  console.log(
    `[auth-purpose-flow] registrationRetryMs=${registrationRetry.elapsedMs}`
  );
  assertAuthenticated(
    registrationRetry,
    'register',
    'Repeated registration confirmation'
  );

  const duplicateRegistration = await startRegistration();
  console.log(
    `[auth-purpose-flow] duplicateRegistrationMs=${duplicateRegistration.elapsedMs} code=${duplicateRegistration.data?.code}`
  );

  if (
    duplicateRegistration.response.status !== 409 ||
    duplicateRegistration.data?.code !== 'PHONE_ALREADY_EXISTS'
  ) {
    fail('Duplicate registration was not rejected.', duplicateRegistration.data);
  }

  const loginStart = await startLogin();
  console.log(
    `[auth-purpose-flow] loginStartMs=${loginStart.elapsedMs} purpose=${loginStart.data?.purpose}`
  );

  if (
    !loginStart.response.ok ||
    loginStart.data?.success !== true ||
    loginStart.data?.purpose !== 'login' ||
    !loginStart.data?.verificationId
  ) {
    fail('Existing-user login did not start correctly.', loginStart.data);
  }

  const loginConfirm = await confirm(loginStart.data.verificationId);
  console.log(`[auth-purpose-flow] loginConfirmMs=${loginConfirm.elapsedMs}`);
  const loginToken = assertAuthenticated(loginConfirm, 'login', 'Login confirmation');

  const profile = await request(`${baseUrl}/api/profile/me`, {
    headers: {
      Authorization: `Bearer ${loginToken}`,
    },
  });
  console.log(
    `[auth-purpose-flow] profileMs=${profile.elapsedMs} httpStatus=${profile.response.status}`
  );

  if (!profile.response.ok || profile.data?.success !== true) {
    fail('The login token could not access the protected profile.', profile.data);
  }

  const speedResults = [
    registrationStart.elapsedMs,
    registrationConfirm.elapsedMs,
    registrationRetry.elapsedMs,
    loginStart.elapsedMs,
    loginConfirm.elapsedMs,
  ];

  if (speedResults.some((elapsedMs) => elapsedMs >= 2000)) {
    fail('A start or confirm request exceeded the 2 second target.', {
      registrationStartMs: registrationStart.elapsedMs,
      registrationConfirmMs: registrationConfirm.elapsedMs,
      registrationRetryMs: registrationRetry.elapsedMs,
      loginStartMs: loginStart.elapsedMs,
      loginConfirmMs: loginConfirm.elapsedMs,
    });
  }

  console.log(
    `[auth-purpose-flow] totalFlowMs=${Math.round(performance.now() - flowStartedAt)}`
  );
  console.log('PASS');
};

main().catch((error) => fail(error.message));
