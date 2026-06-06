const express = require('express');
const { z } = require('zod');

const verificationController = require('../controllers/verificationController');
const { verificationStatusLimiter } = require('../middleware/rateLimits');
const { validateRequest } = require('../middleware/validateRequest');

const router = express.Router();

const verificationStatusParamsSchema = z.object({
  verificationId: z.string().trim().uuid(),
});

router.get(
  '/status/:verificationId',
  verificationStatusLimiter,
  validateRequest(verificationStatusParamsSchema, 'params'),
  verificationController.getVerificationStatusHandler
);

module.exports = router;
