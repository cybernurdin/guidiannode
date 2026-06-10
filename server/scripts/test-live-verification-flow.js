const crypto = require('crypto');
const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { normalizeVerificationToken } = require('../services/whatsappVerificationService');

const args = process.argv.slice(2);

const readArg = (name, fallback = undefined) => {
  const index = args.findIndex((arg) => arg === name || arg.startsWith(`${name}=`));
  if (index < 0) {
    return fallback;
  }

  const arg = args[index];
  return arg.includes('=') ? arg.slice(arg.indexOf('=') + 1) : args[index + 1];
};

const hasFlag = (name) => args.includes(name);
const normalizeBaseUrl = (value) => String(value || '').replace(/\/+$/, '');
const baseUrl = normalizeBaseUrl(
  readArg('--base-url', process.env.API_BASE_URL || 'http://localhost:3000')
);
const phoneNumber = readArg('--phone');
const senderPhone = readArg(
  '--sender',
  process.env.WHATSAPP_TARGET_NUMBER || process.env.WHATSAPP_BUSINESS_NUMBER
);

const fail = (message, details = null) => {
  console.error(`[live-flow] ${message}`);
  if (details) {
    console.error(JSON.stringify(details, null, 2));
  }
  console.log('FAIL');
  process.exit(1);
};

if (!phoneNumber || !senderPhone) {
  fail(
    'Provide --phone and configure WHATSAPP_TARGET_NUMBER or WHATSAPP_BUSINESS_NUMBER.'
  );
}

const parseResponse = async (response) => {
  const raw = await response.text();

  try {
    return raw ? JSON.parse(raw) : {};
  } catch {
    return { raw };
  }
};

const timedRequest = async (url, options = {}) => {
  const startedAt = performance.now();
  const response = await fetch(url, options);
  const data = await parseResponse(response);

  return {
    response,
    data,
    elapsedMs: Math.round(performance.now() - startedAt),
  };
};

const postJson = (url, body, headers = {}) =>
  timedRequest(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });

const getJson = (url, headers = {}) =>
  timedRequest(url, {
    headers,
  });

const buildWebhookSignature = (payload) => {
  const appSecret = String(process.env.WHATSAPP_APP_SECRET || '').trim();
  if (!appSecret) {
    return null;
  }

  return `sha256=${crypto
    .createHmac('sha256', appSecret)
    .update(payload)
    .digest('hex')}`;
};

const spacedToken = (token) =>
  normalizeVerificationToken(token)?.replace(
    /^CM-([A-Z0-9]{2})([A-Z0-9]{3})$/,
    'CM-$1 $2'
  );

const pollForAuthenticatedStatus = async (verificationId) => {
  const deadline = Date.now() + 20000;
  let lastResult = null;

  while (Date.now() < deadline) {
    lastResult = await getJson(
      `${baseUrl}/api/verification/status/${verificationId}`
    );

    if (
      lastResult.data?.verified === true &&
      lastResult.data?.authReady === true &&
      lastResult.data?.session?.access_token
    ) {
      return lastResult;
    }

    if (['expired', 'failed'].includes(lastResult.data?.status)) {
      return lastResult;
    }

    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  return lastResult;
};

const main = async () => {
  const flowStartedAt = performance.now();
  const registrationPayload = {
    full_name: readArg('--name', 'GuardianNode Flow Test'),
    phone_number: phoneNumber,
    quarter: readArg('--quarter', 'Flow Test Quarter'),
    location_permission: false,
    emergency_contact: {
      contact_name: readArg('--contact-name', 'Flow Test Contact'),
      phone_number: readArg('--contact-phone', senderPhone),
      relationship: 'Friend',
    },
  };

  const startResult = await postJson(
    `${baseUrl}/api/auth/register/start-verification`,
    registrationPayload
  );
  console.log(`[live-flow] startVerificationMs=${startResult.elapsedMs}`);

  if (!startResult.response.ok || startResult.data?.success !== true) {
    fail('start-verification failed', startResult.data);
  }

  const verificationId = startResult.data.verificationId;
  const token = startResult.data.token;
  const whatsappUrl = startResult.data.whatsappUrl;
  const cleanToken = normalizeVerificationToken(token);

  if (
    !verificationId ||
    !cleanToken ||
    whatsappUrl !==
      `https://wa.me/${String(senderPhone).replace(/\D/g, '')}?text=${cleanToken}`
  ) {
    fail('start-verification returned an invalid verification payload', {
      verificationId,
      token,
      whatsappUrl,
    });
  }

  const webhookPayload = {
    entry: [
      {
        changes: [
          {
            value: {
              messages: [
                {
                  from: String(senderPhone).replace(/\D/g, ''),
                  type: 'text',
                  text: {
                    body: spacedToken(token),
                  },
                },
              ],
            },
          },
        ],
      },
    ],
  };
  const webhookBody = JSON.stringify(webhookPayload);
  const webhookSignature = buildWebhookSignature(webhookBody);
  const webhookResult = await timedRequest(`${baseUrl}/webhook`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(webhookSignature
        ? { 'x-hub-signature-256': webhookSignature }
        : {}),
    },
    body: webhookBody,
  });

  console.log(
    `[live-flow] webhookHttpStatus=${webhookResult.response.status} webhookMs=${webhookResult.elapsedMs}`
  );

  if (!webhookResult.response.ok) {
    fail('webhook request failed', webhookResult.data);
  }

  const statusResult = await pollForAuthenticatedStatus(verificationId);
  const statusData = statusResult?.data ?? {};
  console.log(
    `[live-flow] statusMs=${statusResult?.elapsedMs} status=${statusData.status} verified=${statusData.verified} authReady=${statusData.authReady}`
  );
  console.log(
    `[live-flow] authToken=${statusData.authToken ? 'yes' : 'no'} session=${
      statusData.session ? 'yes' : 'no'
    } user=${statusData.user ? 'yes' : 'no'}`
  );

  if (
    statusData.status !== 'verified' ||
    statusData.verified !== true ||
    statusData.authReady !== true ||
    !statusData.session?.access_token ||
    !statusData.user?.id
  ) {
    fail('verified status did not produce an authenticated session', statusData);
  }

  const repeatedStatus = await getJson(
    `${baseUrl}/api/verification/status/${verificationId}`
  );
  console.log(
    `[live-flow] repeatedStatusMs=${repeatedStatus.elapsedMs} httpStatus=${repeatedStatus.response.status}`
  );

  if (
    !repeatedStatus.response.ok ||
    repeatedStatus.data?.authReady !== true ||
    !repeatedStatus.data?.session?.access_token
  ) {
    fail('repeated verified status was not idempotent', repeatedStatus.data);
  }

  const authHeaders = {
    Authorization: `Bearer ${statusData.session.access_token}`,
  };
  const profileResult = await getJson(`${baseUrl}/api/profile/me`, authHeaders);
  console.log(
    `[live-flow] profileHttpStatus=${profileResult.response.status} profileMs=${profileResult.elapsedMs}`
  );

  if (!profileResult.response.ok || profileResult.data?.success !== true) {
    fail('authenticated profile access failed', profileResult.data);
  }

  let alertResult = 'not_requested';
  if (hasFlag('--test-sos')) {
    const sosResult = await postJson(
      `${baseUrl}/api/alerts/sos`,
      {
        emergency_type: 'Acceptance test',
        description:
          'Automated GuardianNode authentication acceptance test. Resolve immediately.',
        latitude: 0,
        longitude: 0,
        accuracy: 5,
        source: 'acceptance_test',
      },
      authHeaders
    );

    if (!sosResult.response.ok || !sosResult.data?.data?.id) {
      fail('authenticated SOS creation failed', sosResult.data);
    }

    const alertId = sosResult.data.data.id;
    const resolveResult = await postJson(
      `${baseUrl}/api/alerts/${alertId}/resolve`,
      {},
      authHeaders
    );

    if (!resolveResult.response.ok) {
      fail('test SOS was created but could not be resolved', resolveResult.data);
    }

    alertResult = `created_and_resolved:${alertId}`;
  }

  console.log(`[live-flow] emergencyAlert=${alertResult}`);
  console.log(
    `[live-flow] totalFlowMs=${Math.round(performance.now() - flowStartedAt)}`
  );
  console.log('PASS');
};

main().catch((error) => fail(error.message));
