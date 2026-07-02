const crypto = require('crypto');

const normalizePhoneNumber = (phoneNumber) => {
  const rawPhoneNumber = String(phoneNumber ?? '').trim();
  let digitsOnly = rawPhoneNumber.replace(/\D/g, '');

  if (!digitsOnly) {
    return '';
  }

  if (digitsOnly.length === 9) {
    digitsOnly = '237' + digitsOnly;
  }

  return digitsOnly;
};

const maskPhoneNumber = (phoneNumber) => {
  const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);

  if (normalizedPhoneNumber.length <= 4) {
    return normalizedPhoneNumber;
  }

  const visiblePart = normalizedPhoneNumber.slice(-4);
  return `${normalizedPhoneNumber.slice(0, 3)}***${visiblePart}`;
};

const hashOtpCode = (otpCode) => crypto.createHash('sha256').update(String(otpCode)).digest('hex');

const generateOtpCode = () => String(crypto.randomInt(100000, 1000000));

const nowIso = () => new Date().toISOString();

const addMinutes = (minutes) => new Date(Date.now() + minutes * 60 * 1000).toISOString();

module.exports = {
  addMinutes,
  generateOtpCode,
  hashOtpCode,
  maskPhoneNumber,
  normalizePhoneNumber,
  nowIso,
};
