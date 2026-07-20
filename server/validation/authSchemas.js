const { z } = require('zod');
const { authConfig } = require('../config/authConfig');
const { normalizePhoneNumber } = require('../utils/authUtils');

const phoneNumberSchema = z
  .string()
  .trim()
  .min(8, 'Phone number must be at least 8 digits long')
  .transform(normalizePhoneNumber)
  .refine(
    (value) => /^\+?\d{8,15}$/.test(value),
    'Phone number must contain only digits and may start with +'
  );

const rawCoordinateSchema = z.union([z.number(), z.string().trim().min(1)]);

const latitudeSchema = rawCoordinateSchema
  .transform((value) => Number(value))
  .refine((value) => Number.isFinite(value), 'Latitude must be a valid number')
  .refine((value) => value >= -90 && value <= 90, 'Latitude must be between -90 and 90');

const longitudeSchema = rawCoordinateSchema
  .transform((value) => Number(value))
  .refine((value) => Number.isFinite(value), 'Longitude must be a valid number')
  .refine((value) => value >= -180 && value <= 180, 'Longitude must be between -180 and 180');

const registrationSchema = z
  .object({
    full_name: z.string().trim().min(2, 'Full name is required'),
    phone_number: phoneNumberSchema,
    quarter: z.string().trim().min(2, 'Quarter is required'),
    location_permission: z.coerce.boolean().default(false),
    latitude: latitudeSchema.nullable().optional(),
    longitude: longitudeSchema.nullable().optional(),
    emergency_contact: z.object({
      contact_name: z.string().trim().min(2, 'Emergency contact name is required'),
      phone_number: phoneNumberSchema,
      relationship: z.string().trim().min(2, 'Emergency contact relationship is required'),
    }),
  })
  .superRefine((value, ctx) => {
    const hasLatitude = value.latitude !== undefined && value.latitude !== null;
    const hasLongitude = value.longitude !== undefined && value.longitude !== null;

    if (hasLatitude !== hasLongitude) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Latitude and longitude must be supplied together',
        path: hasLatitude ? ['longitude'] : ['latitude'],
      });
    }
  });

const requestOtpSchema = z.object({
  phone_number: phoneNumberSchema,
});

const otpLengthLabel =
  authConfig.allowedOtpLengths.length === 1
    ? `${authConfig.allowedOtpLengths[0]} digits`
    : `${authConfig.allowedOtpLengths.join(' or ')} digits`;

const verifyOtpSchema = z.object({
  phone_number: phoneNumberSchema,
  otp_code: z
    .string()
    .trim()
    .regex(/^\d+$/, 'OTP code must contain only digits')
    .refine(
      (value) => authConfig.allowedOtpLengths.includes(value.length),
      `OTP code must be ${otpLengthLabel}`
    ),
  otp_session_id: z.string().trim().uuid().optional(),
});

const resendOtpSchema = z.object({
  phone_number: phoneNumberSchema,
  otp_session_id: z.string().trim().uuid().optional(),
});

const passwordSchema = z
  .string()
  .min(6, 'Password must be at least 6 characters long')
  .max(200);

const phoneOnlyLoginSchema = z.object({
  phone_number: phoneNumberSchema,
});

const registerPasswordSchema = z
  .object({
    full_name: z.string().trim().min(2, 'Full name is required'),
    phone_number: phoneNumberSchema,
    email: z.string().trim().email('Enter a valid email').optional(),
    password: passwordSchema,
    quarter: z.string().trim().min(2, 'Quarter is required').optional().default(''),
    location_permission: z.coerce.boolean().optional().default(false),
    latitude: latitudeSchema.nullable().optional(),
    longitude: longitudeSchema.nullable().optional(),
  })
  .superRefine((value, ctx) => {
    const hasLatitude = value.latitude !== undefined && value.latitude !== null;
    const hasLongitude = value.longitude !== undefined && value.longitude !== null;

    if (hasLatitude !== hasLongitude) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Latitude and longitude must be supplied together',
        path: hasLatitude ? ['longitude'] : ['latitude'],
      });
    }
  });

const loginPasswordSchema = z.object({
  identifier: z.string().trim().min(3, 'Enter your phone number or email'),
  password: passwordSchema,
});

module.exports = {
  loginPasswordSchema,
  phoneOnlyLoginSchema,
  registerPasswordSchema,
  registrationSchema,
  requestOtpSchema,
  resendOtpSchema,
  verifyOtpSchema,
};
