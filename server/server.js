require('dotenv').config();
const express = require('express');
const cors = require('cors');

const {
  assertProductionReady,
  buildReadinessSnapshot,
} = require('./config/startupChecks');
const { logAuthModeBanner } = require('./config/authConfig');
const { checkDatabaseReadiness } = require('./config/databaseReadiness');

assertProductionReady();

const authRoutes = require('./routes/authRoutes');
const alertRoutes = require('./routes/alertRoutes');
const locationRoutes = require('./routes/locationRoutes');
const legalRoutes = require('./routes/legalRoutes');
const profileRoutes = require('./routes/profileRoutes');
const verificationRoutes = require('./routes/verificationRoutes');
const webhookRoutes = require('./routes/webhookRoutes');

const app = express();
const PORT = process.env.PORT || 3000;
const jsonBodyLimit = process.env.JSON_BODY_LIMIT || '1mb';
const allowedOrigins = (process.env.CORS_ORIGIN || process.env.CLIENT_ORIGIN || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.disable('x-powered-by');
app.set('trust proxy', 1);

app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  next();
});

app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      if (process.env.NODE_ENV !== 'production' && allowedOrigins.length === 0) {
        callback(null, true);
        return;
      }

      callback(new Error('Origin is not allowed by GuardianNode CORS policy.'));
    },
  })
);
app.use(
  express.json({
    limit: jsonBodyLimit,
    verify(req, res, buffer) {
      req.rawBody = Buffer.from(buffer);
    },
  })
);

// Routes
app.use(legalRoutes);
app.use('/webhook', webhookRoutes);
// SUPER BACKEND PROMPT specifies /api/auth/... for these endpoints
app.use('/api/auth', authRoutes);
app.use('/api/location', locationRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/verification', verificationRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'GuardianNode API',
    uptime_seconds: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

app.get('/ready', async (req, res) => {
  try {
    const database = await checkDatabaseReadiness();

    res.status(database.ok ? 200 : 503).json({
      status: database.ok ? 'ready' : 'not_ready',
      ...buildReadinessSnapshot(),
      database: database.checks,
    });
  } catch (error) {
    console.error('[ready] Database readiness check failed:', error);
    res.status(503).json({
      status: 'not_ready',
      ...buildReadinessSnapshot(),
      database: {
        reachable: false,
      },
    });
  }
});

logAuthModeBanner();

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    code: 'route_not_found',
  });
});

app.use((error, req, res, next) => {
  if (res.headersSent) {
    next(error);
    return;
  }

  const statusCode = error.message?.includes('CORS policy') ? 403 : 500;
  res.status(statusCode).json({
    success: false,
    message:
      statusCode === 403
        ? 'This origin is not allowed to access the GuardianNode API.'
        : 'Internal server error',
    code: statusCode === 403 ? 'cors_origin_forbidden' : 'internal_error',
  });
});

// Start Server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
