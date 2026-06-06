const { authConfig } = require("./authConfig");

const REQUIRED_BACKEND_ENV = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "GOOGLE_MAPS_SERVER_API_KEY",
];

const WHATSAPP_WEBHOOK_ENV = [
  "META_APP_ID",
  "META_BUSINESS_ID",
  "WHATSAPP_API_VERSION",
  "WHATSAPP_TARGET_NUMBER",
  "WHATSAPP_PHONE_NUMBER_ID",
  "WHATSAPP_BUSINESS_ACCOUNT_ID",
  "WHATSAPP_VERIFY_TOKEN",
  "WHATSAPP_APP_SECRET",
  "WEBHOOK_URL",
];

const getMissingEnv = (names) =>
  names.filter((name) => !String(process.env[name] ?? "").trim());

const isPlaceholderValue = (value) =>
  /your-|replace_|paste_|example|placeholder/i.test(String(value || ""));

const hasUsableEnv = (name) => {
  const value = String(process.env[name] || "").trim();
  return Boolean(value) && !isPlaceholderValue(value);
};

const isStrongJwtSecret = (value) => {
  const normalizedValue = String(value || "");
  return normalizedValue.length >= 32 && !/^dev_/i.test(normalizedValue);
};

const isHttpsOrigin = (value) =>
  String(value || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean)
    .every((origin) => origin.startsWith("https://"));

const isValidWebhookUrl = (value) => {
  try {
    const url = new URL(String(value || ""));
    return url.protocol === "https:" && url.pathname === "/webhook";
  } catch (_) {
    return false;
  }
};

const isNumericIdentifier = (value) => /^\d+$/.test(String(value || ""));

const isValidWhatsappApiVersion = (value) =>
  /^v\d+\.\d+$/.test(String(value || ""));

const assertProductionReady = () => {
  const missingBackendEnv = getMissingEnv(REQUIRED_BACKEND_ENV);

  if (missingBackendEnv.length > 0) {
    throw new Error(
      `Missing required backend environment variables: ${missingBackendEnv.join(", ")}`,
    );
  }

  if (process.env.NODE_ENV !== "production") {
    return;
  }

  const sessionSecret = process.env.JWT_SECRET || process.env.SESSION_SECRET;

  if (authConfig.debugAuthMode) {
    throw new Error("DEBUG_AUTH_MODE must be false when NODE_ENV=production.");
  }

  if (isPlaceholderValue(sessionSecret) || !isStrongJwtSecret(sessionSecret)) {
    throw new Error(
      "JWT_SECRET or SESSION_SECRET must be a strong production secret of at least 32 characters and must not use a dev_ prefix.",
    );
  }

  const placeholderBackendEnv = REQUIRED_BACKEND_ENV.filter((name) =>
    isPlaceholderValue(process.env[name]),
  );
  if (placeholderBackendEnv.length > 0) {
    throw new Error(
      `Production environment variables still contain placeholder values: ${placeholderBackendEnv.join(", ")}`,
    );
  }

  const missingWhatsappEnv = getMissingEnv(WHATSAPP_WEBHOOK_ENV);
  if (missingWhatsappEnv.length > 0) {
    throw new Error(
      `Missing WhatsApp webhook environment variables: ${missingWhatsappEnv.join(", ")}`,
    );
  }

  const placeholderWhatsappEnv = WHATSAPP_WEBHOOK_ENV.filter((name) =>
    isPlaceholderValue(process.env[name]),
  );
  if (placeholderWhatsappEnv.length > 0) {
    throw new Error(
      `WhatsApp webhook environment variables still contain placeholder values: ${placeholderWhatsappEnv.join(", ")}`,
    );
  }

  if (!isValidWebhookUrl(process.env.WEBHOOK_URL)) {
    throw new Error(
      "WEBHOOK_URL must be a public HTTPS URL whose path is exactly /webhook.",
    );
  }

  const numericWhatsappEnv = [
    "META_APP_ID",
    "META_BUSINESS_ID",
    "WHATSAPP_TARGET_NUMBER",
    "WHATSAPP_PHONE_NUMBER_ID",
    "WHATSAPP_BUSINESS_ACCOUNT_ID",
  ];
  const invalidNumericWhatsappEnv = numericWhatsappEnv.filter(
    (name) => !isNumericIdentifier(process.env[name]),
  );
  if (invalidNumericWhatsappEnv.length > 0) {
    throw new Error(
      `WhatsApp/Meta identifiers must contain digits only: ${invalidNumericWhatsappEnv.join(", ")}`,
    );
  }

  if (!isValidWhatsappApiVersion(process.env.WHATSAPP_API_VERSION)) {
    throw new Error(
      "WHATSAPP_API_VERSION must use a value such as v22.0.",
    );
  }

  const corsOrigin = process.env.CORS_ORIGIN || process.env.CLIENT_ORIGIN;
  if (!corsOrigin || !isHttpsOrigin(corsOrigin)) {
    throw new Error(
      "CORS_ORIGIN or CLIENT_ORIGIN must be set to HTTPS production origin(s).",
    );
  }

  if (!process.env.APP_BASE_URL || !isHttpsOrigin(process.env.APP_BASE_URL)) {
    throw new Error(
      "APP_BASE_URL must be set to the public HTTPS frontend URL in production.",
    );
  }

};

const buildReadinessSnapshot = () => ({
  service: "GuardianNode API",
  environment: process.env.NODE_ENV || "development",
  auth_mode: authConfig.debugAuthMode
    ? "debug"
    : "whatsapp_inbound",
  checks: {
    supabase_url: Boolean(process.env.SUPABASE_URL),
    supabase_service_role_key: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
    google_maps_server_api_key: Boolean(process.env.GOOGLE_MAPS_SERVER_API_KEY),
    jwt_secret: Boolean(process.env.JWT_SECRET || process.env.SESSION_SECRET),
    cors_origin: Boolean(process.env.CORS_ORIGIN || process.env.CLIENT_ORIGIN),
    app_base_url: Boolean(process.env.APP_BASE_URL),
    whatsapp_verify_token: hasUsableEnv("WHATSAPP_VERIFY_TOKEN"),
    whatsapp_target_number: Boolean(
      process.env.WHATSAPP_TARGET_NUMBER ||
        process.env.WHATSAPP_BUSINESS_NUMBER,
    ),
    whatsapp_phone_number_id: hasUsableEnv("WHATSAPP_PHONE_NUMBER_ID"),
    whatsapp_business_account_id: hasUsableEnv(
      "WHATSAPP_BUSINESS_ACCOUNT_ID",
    ),
    whatsapp_access_token: hasUsableEnv("WHATSAPP_ACCESS_TOKEN"),
    whatsapp_app_secret: hasUsableEnv("WHATSAPP_APP_SECRET"),
    webhook_url: hasUsableEnv("WEBHOOK_URL"),
  },
});

module.exports = {
  assertProductionReady,
  buildReadinessSnapshot,
};
