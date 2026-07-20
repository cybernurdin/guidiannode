const express = require('express');
const authController = require('../controllers/authController');
const { verificationStartLimiter } = require('../middleware/rateLimits');
const { validateRequest } = require('../middleware/validateRequest');
const {
  loginPasswordSchema,
  phoneOnlyLoginSchema,
  registerPasswordSchema,
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

// Demo/competition-only shortcut: no password, no OTP -- just a registered
// phone number. Heavily rate-limited; not suitable for a real deployment.
router.post(
  '/login/phone-only',
  verificationStartLimiter,
  validateRequest(phoneOnlyLoginSchema),
  authController.loginPhoneOnlyHandler
);

router.post(
  '/register/password',
  verificationStartLimiter,
  validateRequest(registerPasswordSchema),
  authController.registerPasswordHandler
);

router.post(
  '/login/password',
  verificationStartLimiter,
  validateRequest(loginPasswordSchema),
  authController.loginPasswordHandler
);

module.exports = router;
