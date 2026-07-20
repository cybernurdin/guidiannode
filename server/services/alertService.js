const { supabaseAdmin } = require('../config/supabaseClient');
const { AppError, wrapDatabaseError } = require('../utils/appError');
const { hasMovedBeyondThreshold, normalizeCoordinates } = require('../utils/geo');
const locationService = require('./locationService');
const mapService = require('./mapService');
const proximityService = require('./proximityService');
const realtimeService = require('./realtimeService');
const userService = require('./userService');
const alertConfirmationService = require('./alertConfirmationService');
const { INCIDENT_CATEGORY, SENSITIVE_CATEGORIES, URGENCY_LEVEL } = require('../constants/incidentTaxonomy');
const { VISIBILITY_LEVEL } = require('../constants/alertTrust');
const { isModeratorOrAdmin, hasApprovedSensitiveRole } = require('../constants/roles');

// The legacy quick-SOS category sheet only ever sends one of these five
// values. The richer free-text report flow sends confirmed_category
// directly instead, so this mapping only exists to give older/simple SOS
// alerts a sensible category for map markers and filters.
const LEGACY_EMERGENCY_TYPE_TO_CATEGORY = Object.freeze({
  security: INCIDENT_CATEGORY.SECURITY_THREAT,
  medical: INCIDENT_CATEGORY.MEDICAL_EMERGENCY,
  fire: INCIDENT_CATEGORY.FIRE,
  accident: INCIDENT_CATEGORY.ROAD_ACCIDENT,
  general_distress: INCIDENT_CATEGORY.OTHER,
});

const ALERTS_TABLE = 'alerts';
const LIVE_LOCATIONS_TABLE = 'live_locations';
const RESPONSES_TABLE = 'responses';
const LIVE_LOCATION_DISTANCE_THRESHOLD_METERS = 15;
const LIVE_LOCATION_MIN_INTERVAL_MS = 5000;
const ADDRESS_REFRESH_DISTANCE_METERS = 60;

// alerts.classification_source is NOT NULL DEFAULT 'user'. An explicit null
// in an insert payload overrides that column default and violates the
// constraint, so this must never resolve to null/undefined -- 'user' is the
// correct fallback for the plain quick-SOS path, which never supplies any
// classification data at all.
const resolveClassificationSource = ({ confirmedCategory, suggestedCategory, classificationSource }) => {
  if (confirmedCategory && suggestedCategory && confirmedCategory !== suggestedCategory) {
    return 'user';
  }

  return classificationSource ?? 'user';
};

const toNullableNumber = (value) => {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const normalizedValue = Number(value);
  return Number.isFinite(normalizedValue) ? normalizedValue : null;
};

const isSchemaCacheMissingColumn = (error, relationName, columnName) => {
  const haystack = [error?.message, error?.details, error?.hint]
    .filter(Boolean)
    .join(' ');
  const match = haystack.match(
    /could not find the ['"]([^'"]+)['"] column of ['"]([^'"]+)['"] in the schema cache/i
  );

  if (!match) {
    return false;
  }

  const [, reportedColumnName, reportedRelationName] = match;

  return (
    reportedRelationName.toLowerCase() === String(relationName).toLowerCase() &&
    reportedColumnName.toLowerCase() === String(columnName).toLowerCase()
  );
};

const isMissingRelation = (error, relationName) => {
  const haystack = [error?.message, error?.details, error?.hint, error?.code]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
  const normalizedRelationName = String(relationName).toLowerCase();

  return (
    error?.code === '42P01' ||
    (haystack.includes('schema cache') &&
      haystack.includes(normalizedRelationName)) ||
    haystack.includes(`relation "${normalizedRelationName}" does not exist`) ||
    haystack.includes(`table '${normalizedRelationName}'`)
  );
};

const insertAlert = async (payload) => {
  let { data, error } = await supabaseAdmin
    .from(ALERTS_TABLE)
    .insert(payload)
    .select()
    .single();

  if (error && isSchemaCacheMissingColumn(error, ALERTS_TABLE, 'updated_at')) {
    const fallbackPayload = { ...payload };
    delete fallbackPayload.updated_at;

    ({ data, error } = await supabaseAdmin
      .from(ALERTS_TABLE)
      .insert(fallbackPayload)
      .select()
      .single());
  }

  if (error) {
    throw wrapDatabaseError(error, ALERTS_TABLE);
  }

  return data;
};

const updateAlertById = async (alertId, payload) => {
  let { error } = await supabaseAdmin
    .from(ALERTS_TABLE)
    .update(payload)
    .eq('id', alertId);

  if (error && isSchemaCacheMissingColumn(error, ALERTS_TABLE, 'updated_at')) {
    const fallbackPayload = { ...payload };
    delete fallbackPayload.updated_at;

    ({ error } = await supabaseAdmin
      .from(ALERTS_TABLE)
      .update(fallbackPayload)
      .eq('id', alertId));
  }

  if (error) {
    throw wrapDatabaseError(error, ALERTS_TABLE);
  }
};

const runBestEffort = async (label, operation, fallbackValue = null) => {
  try {
    return await operation();
  } catch (error) {
    console.warn(`${label} failed:`, error.message);
    return fallbackValue;
  }
};

const normalizeAlertPayload = (alert, liveLocation, victim, extra = {}) => ({
  id: alert.id,
  user_id: alert.user_id,
  victim_id: alert.user_id,
  emergency_type: alert.emergency_type,
  description: alert.description,
  status: alert.status,
  latitude: liveLocation?.latitude ?? alert.latitude,
  longitude: liveLocation?.longitude ?? alert.longitude,
  readable_address: liveLocation?.formatted_address ?? null,
  locality: liveLocation?.locality ?? null,
  accuracy: liveLocation?.accuracy ?? null,
  heading: liveLocation?.heading ?? null,
  speed: liveLocation?.speed ?? null,
  created_at: alert.created_at,
  updated_at: liveLocation?.updated_at ?? alert.updated_at ?? alert.created_at,
  resolved_at: alert.resolved_at ?? null,
  suggested_category: alert.suggested_category ?? null,
  confirmed_category: alert.confirmed_category ?? LEGACY_EMERGENCY_TYPE_TO_CATEGORY[alert.emergency_type] ?? null,
  urgency_level: alert.urgency_level ?? null,
  classification_confidence: alert.classification_confidence ?? null,
  classification_source: alert.classification_source ?? null,
  detected_language: alert.detected_language ?? 'unknown',
  ai_explanation: alert.ai_explanation ?? null,
  recommended_action: alert.recommended_action ?? null,
  requires_moderator_attention: Boolean(alert.requires_moderator_attention),
  verification_status: alert.verification_status ?? 'unverified',
  visibility_level: alert.visibility_level ?? 'standard',
  moderation_status: alert.moderation_status ?? 'pending_review',
  people_affected: alert.people_affected ?? null,
  assistance_needed: alert.assistance_needed ?? [],
  victim:
    victim == null
      ? null
      : {
          id: victim.id,
          full_name: victim.full_name,
          phone_number: victim.phone_number,
          quarter: victim.quarter,
        },
  ...extra,
});

const getAlertById = async (alertId) => {
  const { data, error } = await supabaseAdmin
    .from(ALERTS_TABLE)
    .select('*')
    .eq('id', alertId)
    .maybeSingle();

  if (error) {
    throw wrapDatabaseError(error, ALERTS_TABLE);
  }

  return data;
};

const getLatestLiveLocation = async (alertId, userId) => {
  let query = supabaseAdmin
    .from(LIVE_LOCATIONS_TABLE)
    .select('*')
    .eq('alert_id', alertId);

  if (userId) {
    query = query.eq('user_id', userId);
  }

  const { data, error } = await query.maybeSingle();

  if (error) {
    throw wrapDatabaseError(error, LIVE_LOCATIONS_TABLE);
  }

  return data;
};

const maybeReverseGeocode = async (coordinates) => {
  try {
    return await mapService.reverseGeocode(
      coordinates.latitude,
      coordinates.longitude
    );
  } catch (error) {
    console.warn('Reverse geocoding failed:', error.message);
    return null;
  }
};

const createSosAlert = async ({
  userId,
  emergencyType,
  description,
  latitude,
  longitude,
  accuracy,
  heading,
  speed,
  source = 'device',
  suggestedCategory,
  confirmedCategory,
  urgencyLevel,
  classificationSource,
  classificationConfidence,
  detectedLanguage,
  aiExplanation,
  recommendedAction,
  peopleAffected,
  assistanceNeeded,
  immediateDanger,
}) => {
  const victim = await userService.getUserById(userId);

  if (!victim) {
    throw new AppError('Authenticated user profile could not be found.', 404, 'user_not_found');
  }

  const coordinates = normalizeCoordinates({ latitude, longitude });
  const geocodedAddress = await maybeReverseGeocode(coordinates);
  const nowIso = new Date().toISOString();

  await locationService.updateUserLocation({
    userId,
    locationPermission: true,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
  });

  const finalCategory =
    confirmedCategory ?? suggestedCategory ?? LEGACY_EMERGENCY_TYPE_TO_CATEGORY[emergencyType] ?? null;
  const isSensitiveCategory = finalCategory ? SENSITIVE_CATEGORIES.includes(finalCategory) : false;
  const normalizedClassificationSource = resolveClassificationSource({
    confirmedCategory,
    suggestedCategory,
    classificationSource,
  });
  const finalUrgency = immediateDanger ? URGENCY_LEVEL.CRITICAL : urgencyLevel ?? null;

  const alert = await insertAlert({
    user_id: userId,
    emergency_type: emergencyType,
    description: description ?? '',
    original_description: description ?? '',
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    status: 'active',
    created_at: nowIso,
    updated_at: nowIso,
    suggested_category: suggestedCategory ?? null,
    confirmed_category: confirmedCategory ?? null,
    urgency_level: finalUrgency,
    classification_source: normalizedClassificationSource,
    classification_confidence: classificationConfidence ?? null,
    detected_language: detectedLanguage ?? 'unknown',
    ai_explanation: aiExplanation ?? null,
    recommended_action: recommendedAction ?? null,
    people_affected: peopleAffected ?? null,
    assistance_needed: assistanceNeeded ?? [],
    visibility_level: isSensitiveCategory ? VISIBILITY_LEVEL.SENSITIVE : VISIBILITY_LEVEL.STANDARD,
    requires_moderator_attention: Boolean(immediateDanger) || isSensitiveCategory || finalUrgency === URGENCY_LEVEL.CRITICAL,
  });

  const liveLocation = await upsertLiveAlertLocation({
    alertId: alert.id,
    userId,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    accuracy,
    heading,
    speed,
    source,
    force: true,
    geocodedAddress,
  });

  await runBestEffort('SOS incident log', () =>
    realtimeService.createIncidentLog({
      alertId: alert.id,
      action: 'sos_created',
      performedBy: userId,
      metadata: {
        emergency_type: emergencyType,
        readable_address: liveLocation.formatted_address ?? null,
        locality: liveLocation.locality ?? null,
      },
    })
  );

  const notifications = await runBestEffort(
    'Nearby user notifications',
    () =>
      realtimeService.notifyNearbyUsers({
        alert,
        latestLocation: liveLocation,
        excludeUserId: userId,
      }),
    []
  );

  await runBestEffort('Notification incident log', () =>
    realtimeService.createIncidentLog({
      alertId: alert.id,
      action: 'nearby_users_notified',
      performedBy: userId,
      metadata: {
        recipient_count: notifications.length,
      },
    })
  );

  return normalizeAlertPayload(alert, liveLocation, victim, {
    notified_user_count: notifications.length,
  });
};

const upsertLiveAlertLocation = async ({
  alertId,
  userId,
  latitude,
  longitude,
  accuracy,
  heading,
  speed,
  source = 'device',
  force = false,
  geocodedAddress = null,
}) => {
  const alert = await getAlertById(alertId);

  if (!alert) {
    throw new AppError('Alert could not be found.', 404, 'alert_not_found');
  }

  if (alert.user_id !== userId) {
    throw new AppError(
      'You are not allowed to update the live location for this alert.',
      403,
      'alert_location_forbidden'
    );
  }

  if (alert.status !== 'active') {
    throw new AppError(
      'Live location updates are only allowed for active alerts.',
      409,
      'alert_not_active'
    );
  }

  const coordinates = normalizeCoordinates({ latitude, longitude });
  const existingLocation = await getLatestLiveLocation(alertId, userId);
  const now = Date.now();
  const enoughTimeElapsed =
    !existingLocation ||
    now - new Date(existingLocation.updated_at).getTime() >=
      LIVE_LOCATION_MIN_INTERVAL_MS;
  const movedEnough =
    !existingLocation ||
    hasMovedBeyondThreshold(
      {
        latitude: existingLocation.latitude,
        longitude: existingLocation.longitude,
      },
      coordinates,
      LIVE_LOCATION_DISTANCE_THRESHOLD_METERS
    );

  if (!force && !enoughTimeElapsed && !movedEnough) {
    return {
      ...existingLocation,
      skipped: true,
    };
  }

  const shouldRefreshAddress =
    !existingLocation ||
    !existingLocation.formatted_address ||
    hasMovedBeyondThreshold(
      {
        latitude: existingLocation.latitude,
        longitude: existingLocation.longitude,
      },
      coordinates,
      ADDRESS_REFRESH_DISTANCE_METERS
    );
  const resolvedAddress =
    geocodedAddress ??
    (shouldRefreshAddress ? await maybeReverseGeocode(coordinates) : null);
  const nowIso = new Date().toISOString();

  const { data: liveLocation, error: liveLocationError } = await supabaseAdmin
    .from(LIVE_LOCATIONS_TABLE)
    .upsert(
      {
        alert_id: alertId,
        user_id: userId,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        accuracy: toNullableNumber(accuracy),
        heading: toNullableNumber(heading),
        speed: toNullableNumber(speed),
        source,
        formatted_address:
          resolvedAddress?.formatted_address ??
          existingLocation?.formatted_address ??
          null,
        locality:
          resolvedAddress?.locality ??
          resolvedAddress?.neighborhood ??
          existingLocation?.locality ??
          null,
        created_at: existingLocation?.created_at ?? nowIso,
        updated_at: nowIso,
      },
      {
        onConflict: 'alert_id,user_id',
      }
    )
    .select()
    .single();

  if (liveLocationError) {
    throw wrapDatabaseError(liveLocationError, LIVE_LOCATIONS_TABLE);
  }

  await updateAlertById(alertId, {
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    updated_at: nowIso,
  });

  return {
    ...liveLocation,
    skipped: false,
  };
};

const getNearbyActiveAlerts = async ({
  latitude,
  longitude,
  radiusMeters,
  excludeUserId,
}) => {
  const alerts = await proximityService.listNearbyAlerts({
    latitude,
    longitude,
    radiusMeters,
    excludeUserId,
  });

  if (alerts.length === 0) {
    return alerts;
  }

  const alertIds = alerts.map((alert) => alert.id);
  const [confirmationCounts, myConfirmations] = await runBestEffort(
    'Alert confirmation counts',
    () =>
      Promise.all([
        alertConfirmationService.getConfirmationCounts(alertIds),
        alertConfirmationService.getUserConfirmationsForAlerts(excludeUserId, alertIds),
      ]),
    [new Map(), new Map()]
  );

  return alerts.map((alert) => ({
    ...alert,
    confirmation_counts: confirmationCounts.get(alert.id) ?? {
      community_confirm: 0,
      dispute: 0,
      false_report: 0,
    },
    my_confirmation_type: myConfirmations.get(alert.id) ?? null,
  }));
};

const upsertResponderResponse = async ({ alertId, responderId, status, capability, etaMinutes, note }) => {
  const { data: existingRows, error: existingError } = await supabaseAdmin
    .from(RESPONSES_TABLE)
    .select('*')
    .eq('alert_id', alertId)
    .eq('responder_id', responderId)
    .order('created_at', { ascending: false })
    .limit(1);

  if (existingError) {
    throw existingError;
  }

  const existingResponse = Array.isArray(existingRows)
    ? existingRows[0] ?? null
    : null;
  const updatePayload = {
    response_status: status,
    ...(capability !== undefined ? { capability } : {}),
    ...(etaMinutes !== undefined ? { eta_minutes: etaMinutes } : {}),
    ...(note !== undefined ? { note } : {}),
  };

  if (existingResponse) {
    const query = existingResponse.id
      ? supabaseAdmin
          .from(RESPONSES_TABLE)
          .update(updatePayload)
          .eq('id', existingResponse.id)
      : supabaseAdmin
          .from(RESPONSES_TABLE)
          .update(updatePayload)
          .eq('alert_id', alertId)
          .eq('responder_id', responderId);

    const { data, error } = await query.select();

    if (error) {
      throw error;
    }

    return Array.isArray(data) && data.length > 0
      ? data[0]
      : { ...existingResponse, ...updatePayload };
  }

  const insertPayload = {
    alert_id: alertId,
    responder_id: responderId,
    response_status: status,
    capability: capability ?? null,
    eta_minutes: etaMinutes ?? null,
    note: note ?? null,
    created_at: new Date().toISOString(),
  };

  let { data, error } = await supabaseAdmin
    .from(RESPONSES_TABLE)
    .insert(insertPayload)
    .select()
    .single();

  if (error && isSchemaCacheMissingColumn(error, RESPONSES_TABLE, 'created_at')) {
    const fallbackPayload = { ...insertPayload };
    delete fallbackPayload.created_at;

    ({ data, error } = await supabaseAdmin
      .from(RESPONSES_TABLE)
      .insert(fallbackPayload)
      .select()
      .single());
  }

  if (error) {
    throw error;
  }

  return data;
};

const respondToAlert = async ({
  alertId,
  responderId,
  status = 'on_the_way',
  latitude,
  longitude,
  accuracy,
  heading,
  speed,
  source = 'device',
  capability,
  etaMinutes,
  note,
}) => {
  const alert = await getAlertById(alertId);

  if (!alert) {
    throw new AppError('Alert could not be found.', 404, 'alert_not_found');
  }

  if (alert.status !== 'active') {
    throw new AppError(
      'This alert is no longer active.',
      409,
      'alert_not_active'
    );
  }

  if (alert.user_id === responderId) {
    throw new AppError(
      'You cannot respond to your own active alert.',
      409,
      'self_response_not_allowed'
    );
  }

  let response = null;
  let syncStatus = 'incident_logged';

  try {
    response = await upsertResponderResponse({ alertId, responderId, status, capability, etaMinutes, note });
    syncStatus = 'response_record_synced';
  } catch (error) {
    const fallbackReason = isMissingRelation(error, RESPONSES_TABLE)
      ? 'responses_table_unavailable'
      : 'responses_write_failed';
    console.warn(`Responder response fallback (${fallbackReason}):`, error.message);
    syncStatus = fallbackReason;
  }

  await runBestEffort('Responder response incident log', () =>
    realtimeService.createIncidentLog({
      alertId,
      action: `responder_${status}`,
      performedBy: responderId,
      metadata: {
        response_status: status,
        response_sync_status: syncStatus,
        responder_location:
          latitude !== undefined && longitude !== undefined
            ? {
                latitude,
                longitude,
                accuracy: toNullableNumber(accuracy),
                heading: toNullableNumber(heading),
                speed: toNullableNumber(speed),
                source,
              }
            : null,
      },
    })
  );

  const victim = await userService.getUserById(alert.user_id);
  const liveLocation = await getLatestLiveLocation(alertId, alert.user_id);

  return {
    response:
      response ?? {
        alert_id: alertId,
        responder_id: responderId,
        response_status: status,
      },
    sync_status: syncStatus,
    alert: normalizeAlertPayload(alert, liveLocation, victim),
  };
};

const getResponderFollowDetails = async ({
  alertId,
  responderLatitude,
  responderLongitude,
  travelMode = 'DRIVE',
  requestingUser,
}) => {
  const alert = await getAlertById(alertId);

  if (!alert || alert.status !== 'active') {
    throw new AppError('Active alert could not be found.', 404, 'alert_not_found');
  }

  const isOwner = requestingUser?.id === alert.user_id;
  const isAuthorized = isOwner || isModeratorOrAdmin(requestingUser) || hasApprovedSensitiveRole(requestingUser);

  if (alert.visibility_level === VISIBILITY_LEVEL.SENSITIVE && !isAuthorized) {
    throw new AppError(
      'This report has restricted visibility. Only an approved responder or moderator can navigate to it.',
      403,
      'sensitive_alert_restricted'
    );
  }

  const victim = await userService.getUserById(alert.user_id);
  const liveLocation = await getLatestLiveLocation(alertId, alert.user_id);
  const coordinates = normalizeCoordinates({
    latitude: liveLocation?.latitude ?? alert.latitude,
    longitude: liveLocation?.longitude ?? alert.longitude,
  });
  const geocodedAddress =
    liveLocation?.formatted_address || liveLocation?.locality
      ? null
      : await maybeReverseGeocode(coordinates);
  const route =
    responderLatitude !== undefined && responderLongitude !== undefined
      ? await runBestEffort(
          'Responder route lookup',
          () =>
            mapService.getRoute({
              origin: {
                latitude: responderLatitude,
                longitude: responderLongitude,
              },
              destination: coordinates,
              travelMode,
            }),
          null
        )
      : null;
  const resolvedLiveLocation = {
    ...(liveLocation ?? {}),
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    formatted_address:
      liveLocation?.formatted_address ?? geocodedAddress?.formatted_address ?? null,
    locality: liveLocation?.locality ?? geocodedAddress?.locality ?? null,
  };

  return {
    alert: normalizeAlertPayload(alert, resolvedLiveLocation, victim),
    victim: victim
      ? {
          id: victim.id,
          full_name: victim.full_name,
          phone_number: victim.phone_number,
          quarter: victim.quarter,
        }
      : null,
    victim_location: {
      latitude: resolvedLiveLocation.latitude,
      longitude: resolvedLiveLocation.longitude,
      readable_address: resolvedLiveLocation.formatted_address,
      locality: resolvedLiveLocation.locality,
      accuracy: resolvedLiveLocation.accuracy ?? null,
      heading: resolvedLiveLocation.heading ?? null,
      speed: resolvedLiveLocation.speed ?? null,
      updated_at:
        resolvedLiveLocation.updated_at ?? alert.updated_at ?? alert.created_at,
    },
    route,
  };
};

const resolveAlert = async ({ alertId, userId }) => {
  const alert = await getAlertById(alertId);

  if (!alert) {
    throw new AppError('Alert could not be found.', 404, 'alert_not_found');
  }

  if (alert.user_id !== userId) {
    throw new AppError(
      'You are not allowed to resolve this alert.',
      403,
      'alert_resolve_forbidden'
    );
  }

  if (alert.status === 'resolved') {
    const victim = await userService.getUserById(alert.user_id);
    const liveLocation = await getLatestLiveLocation(alert.id, alert.user_id);
    return normalizeAlertPayload(alert, liveLocation, victim);
  }

  const nowIso = new Date().toISOString();

  await updateAlertById(alertId, {
    status: 'resolved',
    resolved_at: nowIso,
    updated_at: nowIso,
  });

  const resolvedAlert = await getAlertById(alertId);
  const victim = await userService.getUserById(userId);
  const liveLocation = await getLatestLiveLocation(alertId, userId);

  await runBestEffort('Resolve incident log', () =>
    realtimeService.createIncidentLog({
      alertId,
      action: 'sos_resolved',
      performedBy: userId,
      metadata: {
        resolved_at: nowIso,
      },
    })
  );

  return normalizeAlertPayload(resolvedAlert, liveLocation, victim);
};

module.exports = {
  createSosAlert,
  getAlertById,
  getLatestLiveLocation,
  getNearbyActiveAlerts,
  getResponderFollowDetails,
  respondToAlert,
  resolveAlert,
  upsertLiveAlertLocation,
  resolveClassificationSource,
};
