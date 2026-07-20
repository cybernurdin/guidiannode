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

// scrypt keeps this dependency-free (no native bcrypt build step) while
// still being a deliberately slow, salted KDF -- suitable for password
// storage. Stored format is "salt:hash", both hex.
const SCRYPT_KEY_LENGTH = 64;

const hashPassword = (password) => {
  const salt = crypto.randomBytes(16).toString('hex');
  const derivedKey = crypto.scryptSync(String(password), salt, SCRYPT_KEY_LENGTH);
  return `${salt}:${derivedKey.toString('hex')}`;
};

const verifyPassword = (password, storedHash) => {
  if (!storedHash || !storedHash.includes(':')) {
    return false;
  }

  const [salt, hashHex] = storedHash.split(':');

  try {
    const derivedKey = crypto.scryptSync(String(password), salt, SCRYPT_KEY_LENGTH);
    const storedKey = Buffer.from(hashHex, 'hex');

    return (
      storedKey.length === derivedKey.length &&
      crypto.timingSafeEqual(storedKey, derivedKey)
    );
  } catch (_error) {
    return false;
  }
};

module.exports = {
  addMinutes,
  generateOtpCode,
  hashOtpCode,
  hashPassword,
  maskPhoneNumber,
  normalizePhoneNumber,
  nowIso,
  verifyPassword,
};
