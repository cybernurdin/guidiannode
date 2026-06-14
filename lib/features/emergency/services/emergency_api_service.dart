import '../../../core/services/api_client.dart';
import '../models/emergency_models.dart';

class EmergencyApiService {
  static Future<Map<String, dynamic>> updateUserLocation({
    required bool locationPermission,
    PositionSnapshot? snapshot,
  }) async {
    final response = await _request(
      'POST',
      '/api/location/update',
      body: snapshot == null
          ? {'location_permission': locationPermission}
          : snapshot.toUserLocationPayload(
              locationPermission: locationPermission,
            ),
    );

    return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  }

  static Future<EmergencyAlert> createSosAlert({
    required String emergencyType,
    required PositionSnapshot snapshot,
    String description = '',
  }) async {
    final response = await _request(
      'POST',
      '/api/alerts/sos',
      body: {
        'emergency_type': emergencyType,
        'description': description,
        ...snapshot.toAlertLocationPayload(),
      },
    );

    return EmergencyAlert.fromJson(
      Map<String, dynamic>.from(response['data'] as Map? ?? const {}),
    );
  }

  static Future<PositionSnapshot> updateAlertLocation({
    required String alertId,
    required PositionSnapshot snapshot,
  }) async {
    final response = await _request(
      'POST',
      '/api/alerts/$alertId/location',
      body: snapshot.toAlertLocationPayload(),
    );

    return PositionSnapshot.fromJson(
      Map<String, dynamic>.from(response['data'] as Map? ?? const {}),
    );
  }

  static Future<EmergencyAlert> resolveAlert({required String alertId}) async {
    final response = await _request('POST', '/api/alerts/$alertId/resolve');

    return EmergencyAlert.fromJson(
      Map<String, dynamic>.from(response['data'] as Map? ?? const {}),
    );
  }

  static Future<List<EmergencyAlert>> fetchNearbyAlerts({
    required PositionSnapshot center,
    int radiusMeters = 3000,
  }) async {
    final response = await _request(
      'GET',
      '/api/alerts/nearby',
      query: {
        'lat': center.latitude.toString(),
        'lng': center.longitude.toString(),
        'radius_meters': radiusMeters.toString(),
      },
    );
    final data = Map<String, dynamic>.from(
      response['data'] as Map? ?? const {},
    );
    final alerts = List<Map<String, dynamic>>.from(
      data['alerts'] as List? ?? const <Map<String, dynamic>>[],
    );

    return alerts.map(EmergencyAlert.fromJson).toList();
  }

  static Future<FollowDetails> fetchFollowDetails({
    required String alertId,
    required PositionSnapshot responderLocation,
  }) async {
    final response = await _request(
      'GET',
      '/api/alerts/$alertId/follow',
      query: {
        'origin_lat': responderLocation.latitude.toString(),
        'origin_lng': responderLocation.longitude.toString(),
      },
    );

    return FollowDetails.fromJson(
      Map<String, dynamic>.from(response['data'] as Map? ?? const {}),
    );
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    return ApiClient.request(method, path, body: body, query: query);
  }
}
