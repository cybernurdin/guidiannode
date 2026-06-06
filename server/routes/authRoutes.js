const express = require('express');
const authController = require('../controllers/authController');
const { verificationStartLimiter } = require('../middleware/rateLimits');
const { validateRequest } = require('../middleware/validateRequest');
const {
  registrationSchema,
  requestOtpSchema,
  resendOtpSchema,
  verifyOtpSchema,
} = require('../validation/authSchemas');

const router = express.Router();

router.post(
  '/request-otp',
  verificationStartLimiter,
  validateRequest(requestOtpSchema),
  authController.requestOtpHandler
);

router.post(
  '/login/start-verification',
  verificationStartLimiter,
  validateRequest(requestOtpSchema),
  authController.requestOtpHandler
);

router.post(
  '/verify-otp',
  validateRequest(verifyOtpSchema),
  authController.verifyOtpHandler
);

router.post(
  '/register/start-verification',
  verificationStartLimiter,
  validateRequest(registrationSchema),
  authController.startRegistrationVerificationHandler
);

router.post(
  '/register',
  verificationStartLimiter,
  validateRequest(registrationSchema),
  authController.registerHandler
);

router.post(
  '/resend-otp',
  validateRequest(resendOtpSchema),
  authController.resendOtpHandler
);

module.exports = router;
