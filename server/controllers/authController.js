const authService = require('../services/authService');
const { AppError } = require('../utils/appError');

const handleErrorResponse = (res, error, label) => {
  const statusCode = error instanceof AppError ? error.statusCode : 500;
  const message = error instanceof AppError ? error.message : 'Internal server error';

  if (statusCode >= 500) {
    console.error(`${label}:`, error);
  } else {
    console.warn(`${label}:`, error.message);
  }

  return res.status(statusCode).json({
    success: false,
    message,
    code: error.code,
    details: statusCode < 500 ? error.details ?? null : null,
  });
};

const requestOtpHandler = async (req, res) => {
  try {
    const response = await authService.startLoginOtp(req.validatedBody ?? req.body);
    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Login Verification Error');
  }
};

const verifyOtpHandler = async (req, res) => {
  try {
    const response = await authService.verifyOtp(req.validatedBody ?? req.body);
    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Verify OTP Error');
  }
};

const registerHandler = async (req, res) => {
  try {
    const response = await authService.startRegistrationWhatsappVerification(
      req.validatedBody ?? req.body
    );
    return res.status(201).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Registration Error');
  }
};

const startRegistrationVerificationHandler = async (req, res) => {
  try {
    const response = await authService.startRegistrationWhatsappVerification(
      req.validatedBody ?? req.body
    );
    return res.status(201).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Registration Verification Error');
  }
};

const resendOtpHandler = async (req, res) => {
  try {
    const response = await authService.resendOtp(req.validatedBody ?? req.body);
    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Resend OTP Error');
  }
};

const loginPhoneOnlyHandler = async (req, res) => {
  try {
    const response = await authService.loginWithPhoneOnly(
      req.validatedBody ?? req.body
    );
    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Phone-Only Login Error');
  }
};

const registerPasswordHandler = async (req, res) => {
  try {
    const response = await authService.registerWithPassword(
      req.validatedBody ?? req.body
    );
    return res.status(201).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Password Registration Error');
  }
};

const loginPasswordHandler = async (req, res) => {
  try {
    const response = await authService.loginWithPassword(
      req.validatedBody ?? req.body
    );
    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Password Login Error');
  }
};

module.exports = {
  requestOtpHandler,
  resendOtpHandler,
  verifyOtpHandler,
  registerHandler,
  startRegistrationVerificationHandler,
  loginPhoneOnlyHandler,
  registerPasswordHandler,
  loginPasswordHandler,
};
