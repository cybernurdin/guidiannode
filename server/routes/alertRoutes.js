const express = require('express');
const { verifySession } = require('../middleware/verifySession');
const { validateRequest } = require('../middleware/validateRequest');
const alertController = require('../controllers/alertController');
const {
  alertIdParamSchema,
  createSosAlertSchema,
  nearbyAlertsQuerySchema,
  responderFollowQuerySchema,
  updateAlertLocationSchema,
} = require('../validation/alertSchemas');

const router = express.Router();

router.post(
  '/sos',
  verifySession,
  validateRequest(createSosAlertSchema),
  alertController.createSosAlertHandler
);

router.get(
  '/nearby',
  verifySession,
  validateRequest(nearbyAlertsQuerySchema, 'query'),
  alertController.getNearbyAlertsHandler
);

router.get(
  '/:alertId/follow',
  verifySession,
  validateRequest(alertIdParamSchema, 'params'),
  validateRequest(responderFollowQuerySchema, 'query'),
  alertController.getResponderFollowDetailsHandler
);

router.post(
  '/:alertId/location',
  verifySession,
  validateRequest(alertIdParamSchema, 'params'),
  validateRequest(updateAlertLocationSchema),
  alertController.updateLiveAlertLocationHandler
);

router.post(
  '/:alertId/resolve',
  verifySession,
  validateRequest(alertIdParamSchema, 'params'),
  alertController.resolveAlertHandler
);

module.exports = router;
