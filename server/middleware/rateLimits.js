const { rateLimit } = require('express-rate-limit');

const buildRateLimitHandler = (message, code) => (req, res) =>
  res.status(429).json({
    success: false,
    message,
    code,
  });

const verificationStartLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: buildRateLimitHandler(
    'Too many verification requests. Please wait before trying again.',
    'verification_rate_limited'
  ),
});

const verificationStatusLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 240,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: buildRateLimitHandler(
    'Too many verification status checks. Please wait before retrying.',
    'verification_status_rate_limited'
  ),
});

const verificationConfirmLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: buildRateLimitHandler(
    'Too many verification confirmation attempts. Please wait before retrying.',
    'verification_confirm_rate_limited'
  ),
});

module.exports = {
  verificationConfirmLimiter,
  verificationStartLimiter,
  verificationStatusLimiter,
};
