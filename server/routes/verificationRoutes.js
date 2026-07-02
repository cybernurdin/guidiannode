const express = require('express');
const { z } = require('zod');

const verificationController = require('../controllers/verificationController');
const {
  verificationConfirmLimiter,
  verificationStatusLimiter,
} = require('../middleware/rateLimits');
const { validateRequest } = require('../middleware/validateRequest');

const router = express.Router();

const verificationStatusParamsSchema = z.object({
  verificationId: z.string().trim().uuid(),
});

const confirmWhatsappClickSchema = z.object({
  verificationId: z.string().trim().uuid().optional(),
  otp_session_id: z.string().trim().uuid().optional(),
  phone_number: z.string().trim(),
}).refine((data) => data.verificationId || data.otp_session_id, {
  message: 'Either verificationId or otp_session_id must be provided',
  path: ['verificationId'],
});

router.get(
  '/status/:verificationId',
  verificationStatusLimiter,
  validateRequest(verificationStatusParamsSchema, 'params'),
  verificationController.getVerificationStatusHandler
);

router.post(
  '/confirm-whatsapp-click',
  verificationConfirmLimiter,
  validateRequest(confirmWhatsappClickSchema),
  verificationController.confirmWhatsappClickHandler
);

module.exports = router;
