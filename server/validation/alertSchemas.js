const { z } = require('zod');

const rawCoordinateSchema = z.union([z.number(), z.string().trim().min(1)]);
const rawOptionalNumericSchema = z
  .union([z.number(), z.string().trim().min(1)])
  .optional()
  .nullable();

const latitudeSchema = rawCoordinateSchema
  .transform((value) => Number(value))
  .refine((value) => Number.isFinite(value), 'Latitude must be a valid number')
  .refine((value) => value >= -90 && value <= 90, 'Latitude must be between -90 and 90');

const longitudeSchema = rawCoordinateSchema
  .transform((value) => Number(value))
  .refine((value) => Number.isFinite(value), 'Longitude must be a valid number')
  .refine((value) => value >= -180 && value <= 180, 'Longitude must be between -180 and 180');

const optionalNumericSchema = rawOptionalNumericSchema.transform((value) => {
  if (value === undefined || value === null || value === '') {
    return null;
  }

  const normalizedValue = Number(value);
  return Number.isFinite(normalizedValue) ? normalizedValue : null;
});

const createSosAlertSchema = z.object({
  emergency_type: z.string().trim().min(2).max(80),
  description: z.string().trim().max(500).optional().default(''),
  latitude: latitudeSchema,
  longitude: longitudeSchema,
  accuracy: optionalNumericSchema.optional(),
  heading: optionalNumericSchema.optional(),
  speed: optionalNumericSchema.optional(),
  source: z.string().trim().min(2).max(50).optional().default('device'),
});

const updateAlertLocationSchema = z.object({
  latitude: latitudeSchema,
  longitude: longitudeSchema,
  accuracy: optionalNumericSchema.optional(),
  heading: optionalNumericSchema.optional(),
  speed: optionalNumericSchema.optional(),
  source: z.string().trim().min(2).max(50).optional().default('device'),
});

const nearbyAlertsQuerySchema = z.object({
  lat: latitudeSchema,
  lng: longitudeSchema,
  radius_meters: z
    .union([z.number(), z.string().trim().min(1)])
    .optional()
    .transform((value) => {
      if (value === undefined) {
        return 3000;
      }

      const normalizedValue = Number(value);
      return Number.isFinite(normalizedValue) ? normalizedValue : 3000;
    })
    .refine((value) => value > 0 && value <= 20000, 'radius_meters must be between 1 and 20000'),
});

const responderFollowQuerySchema = z
  .object({
    origin_lat: latitudeSchema.optional(),
    origin_lng: longitudeSchema.optional(),
    travel_mode: z
      .enum(['DRIVE', 'TWO_WHEELER', 'WALK'])
      .optional()
      .default('DRIVE'),
  })
  .superRefine((value, ctx) => {
    const hasOriginLatitude = value.origin_lat !== undefined;
    const hasOriginLongitude = value.origin_lng !== undefined;

    if (hasOriginLatitude !== hasOriginLongitude) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: hasOriginLatitude ? ['origin_lng'] : ['origin_lat'],
        message: 'origin_lat and origin_lng must be supplied together.',
      });
    }
  });

const respondToAlertSchema = z.object({
  status: z
    .enum(['accepted', 'on_the_way', 'arrived', 'cancelled', 'stopped'])
    .optional()
    .default('on_the_way'),
  latitude: latitudeSchema.optional(),
  longitude: longitudeSchema.optional(),
  accuracy: optionalNumericSchema.optional(),
  heading: optionalNumericSchema.optional(),
  speed: optionalNumericSchema.optional(),
  source: z.string().trim().min(2).max(50).optional().default('device'),
});

const alertIdParamSchema = z.object({
  alertId: z.string().trim().uuid('alertId must be a valid UUID'),
});

module.exports = {
  alertIdParamSchema,
  createSosAlertSchema,
  nearbyAlertsQuerySchema,
  respondToAlertSchema,
  responderFollowQuerySchema,
  updateAlertLocationSchema,
};
