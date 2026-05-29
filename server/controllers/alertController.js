const alertService = require('../services/alertService');
const { sendError, sendSuccess } = require('../utils/apiResponse');

const createSosAlertHandler = async (req, res) => {
  try {
    const payload = req.validated?.body ?? req.body;
    const alert = await alertService.createSosAlert({
      userId: req.user.id,
      emergencyType: payload.emergency_type,
      description: payload.description,
      latitude: payload.latitude,
      longitude: payload.longitude,
      accuracy: payload.accuracy,
      heading: payload.heading,
      speed: payload.speed,
      source: payload.source,
    });

    return sendSuccess(res, {
      statusCode: 201,
      message: 'SOS alert created successfully.',
      data: alert,
    });
  } catch (error) {
    return sendError(res, error, { label: 'Create SOS Alert Error' });
  }
};

const updateLiveAlertLocationHandler = async (req, res) => {
  try {
    const params = req.validated?.params ?? req.params;
    const payload = req.validated?.body ?? req.body;
    const liveLocation = await alertService.upsertLiveAlertLocation({
      alertId: params.alertId,
      userId: req.user.id,
      latitude: payload.latitude,
      longitude: payload.longitude,
      accuracy: payload.accuracy,
      heading: payload.heading,
      speed: payload.speed,
      source: payload.source,
    });

    return sendSuccess(res, {
      statusCode: 200,
      message: liveLocation.skipped
        ? 'Live location update skipped because movement was below the configured threshold.'
        : 'Live alert location updated successfully.',
      data: liveLocation,
    });
  } catch (error) {
    return sendError(res, error, { label: 'Update Live Alert Location Error' });
  }
};

const getNearbyAlertsHandler = async (req, res) => {
  try {
    const query = req.validated?.query ?? req.query;
    const alerts = await alertService.getNearbyActiveAlerts({
      latitude: query.lat,
      longitude: query.lng,
      radiusMeters: query.radius_meters,
      excludeUserId: req.user.id,
    });

    return sendSuccess(res, {
      statusCode: 200,
      message: 'Nearby active alerts fetched successfully.',
      data: {
        center: {
          latitude: query.lat,
          longitude: query.lng,
        },
        radius_meters: query.radius_meters,
        alerts,
      },
    });
  } catch (error) {
    return sendError(res, error, { label: 'Get Nearby Alerts Error' });
  }
};

const getResponderFollowDetailsHandler = async (req, res) => {
  try {
    const params = req.validated?.params ?? req.params;
    const query = req.validated?.query ?? req.query;
    const followDetails = await alertService.getResponderFollowDetails({
      alertId: params.alertId,
      responderLatitude: query.origin_lat,
      responderLongitude: query.origin_lng,
      travelMode: query.travel_mode,
    });

    return sendSuccess(res, {
      statusCode: 200,
      message: 'Responder follow details fetched successfully.',
      data: followDetails,
    });
  } catch (error) {
    return sendError(res, error, { label: 'Get Responder Follow Details Error' });
  }
};

const resolveAlertHandler = async (req, res) => {
  try {
    const params = req.validated?.params ?? req.params;
    const alert = await alertService.resolveAlert({
      alertId: params.alertId,
      userId: req.user.id,
    });

    return sendSuccess(res, {
      statusCode: 200,
      message: 'SOS alert resolved successfully.',
      data: alert,
    });
  } catch (error) {
    return sendError(res, error, { label: 'Resolve Alert Error' });
  }
};

module.exports = {
  createSosAlertHandler,
  getNearbyAlertsHandler,
  getResponderFollowDetailsHandler,
  resolveAlertHandler,
  updateLiveAlertLocationHandler,
};
