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
    status: 'failed',
    message,
    code: error.code,
    details: statusCode < 500 ? error.details ?? null : null,
  });
};

const getVerificationStatusHandler = async (req, res) => {
  try {
    const response = await authService.getVerificationStatus({
      verificationId: req.validated?.params?.verificationId ?? req.params.verificationId,
    });

    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Verification Status Error');
  }
};

const confirmWhatsappClickHandler = async (req, res) => {
  try {
    const response = await authService.confirmWhatsappClick(req.validatedBody ?? req.body);
    return res.status(200).json(response);
  } catch (error) {
    return handleErrorResponse(res, error, 'Confirm Whatsapp Click Error');
  }
};

module.exports = {
  getVerificationStatusHandler,
  confirmWhatsappClickHandler,
};
