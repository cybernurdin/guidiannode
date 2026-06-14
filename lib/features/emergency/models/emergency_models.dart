import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum GuardianLocationStatus {
  notRequested,
  fetching,
  ready,
  usingLastKnown,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  failed,
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

class PositionSnapshot {
  const PositionSnapshot({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.readableAddress,
    this.locality,
    this.capturedAt,
    this.skipped = false,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final String? readableAddress;
  final String? locality;
  final DateTime? capturedAt;
  final bool skipped;

  LatLng get latLng => LatLng(latitude, longitude);

  String get displayAddress => readableAddress?.trim().isNotEmpty == true
      ? readableAddress!.trim()
      : locality?.trim().isNotEmpty == true
      ? locality!.trim()
      : 'Location ready';

  PositionSnapshot copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? heading,
    double? speed,
    String? readableAddress,
    String? locality,
    DateTime? capturedAt,
    bool? skipped,
  }) {
    return PositionSnapshot(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      readableAddress: readableAddress ?? this.readableAddress,
      locality: locality ?? this.locality,
      capturedAt: capturedAt ?? this.capturedAt,
      skipped: skipped ?? this.skipped,
    );
  }

  factory PositionSnapshot.fromPosition(Position position) {
    return PositionSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      heading: position.heading,
      speed: position.speed,
      capturedAt: position.timestamp,
    );
  }

  factory PositionSnapshot.fromJson(Map<String, dynamic> json) {
    return PositionSnapshot(
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      accuracy: _toDouble(json['accuracy']),
      heading: _toDouble(json['heading']),
      speed: _toDouble(json['speed']),
      readableAddress:
          json['readable_address']?.toString() ??
          json['formatted_address']?.toString(),
      locality: json['locality']?.toString(),
      capturedAt:
          _toDateTime(json['updated_at']) ??
          _toDateTime(json['captured_at']) ??
          _toDateTime(json['created_at']),
      skipped: json['skipped'] == true,
    );
  }

  Map<String, dynamic> toUserLocationPayload({
    required bool locationPermission,
    String source = 'device',
  }) {
    return {
      'location_permission': locationPermission,
      if (locationPermission) ...{
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'heading': heading,
        'speed': speed,
        'source': source,
      },
    };
  }

  Map<String, dynamic> toAlertLocationPayload({String source = 'device'}) {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
      'source': source,
    };
  }
}

class VictimProfile {
  const VictimProfile({
    required this.id,
    this.fullName,
    this.phoneNumber,
    this.quarter,
  });

  final String id;
  final String? fullName;
  final String? phoneNumber;
  final String? quarter;

  factory VictimProfile.fromJson(Map<String, dynamic> json) {
    return VictimProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      quarter: json['quarter']?.toString(),
    );
  }
}

class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.userId,
    required this.emergencyType,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.description,
    this.readableAddress,
    this.locality,
    this.distanceMeters,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.victim,
  });

  final String id;
  final String userId;
  final String emergencyType;
  final String? description;
  final double latitude;
  final double longitude;
  final String status;
  final String? readableAddress;
  final String? locality;
  final double? distanceMeters;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final VictimProfile? victim;

  LatLng get latLng => LatLng(latitude, longitude);

  String get displayAddress => readableAddress?.trim().isNotEmpty == true
      ? readableAddress!.trim()
      : locality?.trim().isNotEmpty == true
      ? locality!.trim()
      : 'Location unavailable';

  EmergencyAlert copyWith({
    double? latitude,
    double? longitude,
    String? readableAddress,
    String? locality,
    DateTime? updatedAt,
  }) {
    return EmergencyAlert(
      id: id,
      userId: userId,
      emergencyType: emergencyType,
      description: description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status,
      readableAddress: readableAddress ?? this.readableAddress,
      locality: locality ?? this.locality,
      distanceMeters: distanceMeters,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt,
      victim: victim,
    );
  }

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    final victimJson = json['victim'];
    return EmergencyAlert(
      id: json['id']?.toString() ?? '',
      userId:
          json['user_id']?.toString() ?? json['victim_id']?.toString() ?? '',
      emergencyType: json['emergency_type']?.toString() ?? 'general_distress',
      description: json['description']?.toString(),
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      status: json['status']?.toString() ?? 'active',
      readableAddress:
          json['readable_address']?.toString() ??
          json['formatted_address']?.toString(),
      locality: json['locality']?.toString(),
      distanceMeters: _toDouble(json['distance_meters']),
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      resolvedAt: _toDateTime(json['resolved_at']),
      victim: victimJson is Map<String, dynamic>
          ? VictimProfile.fromJson(victimJson)
          : null,
    );
  }
}

class RouteSummary {
  const RouteSummary({
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    this.encodedPolyline,
    this.travelMode,
  });

  final double distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final String? encodedPolyline;
  final String? travelMode;

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      distanceMeters: _toDouble(json['distance_meters']) ?? 0,
      distanceText: json['distance_text']?.toString() ?? '0 m',
      durationSeconds: (_toDouble(json['duration_seconds']) ?? 0).round(),
      durationText: json['duration_text']?.toString() ?? '0 min',
      encodedPolyline: json['encoded_polyline']?.toString(),
      travelMode: json['travel_mode']?.toString(),
    );
  }
}

class FollowDetails {
  const FollowDetails({
    required this.alert,
    required this.victimLocation,
    this.victim,
    this.route,
  });

  final EmergencyAlert alert;
  final VictimProfile? victim;
  final PositionSnapshot victimLocation;
  final RouteSummary? route;

  FollowDetails copyWith({
    EmergencyAlert? alert,
    VictimProfile? victim,
    PositionSnapshot? victimLocation,
    RouteSummary? route,
  }) {
    return FollowDetails(
      alert: alert ?? this.alert,
      victim: victim ?? this.victim,
      victimLocation: victimLocation ?? this.victimLocation,
      route: route ?? this.route,
    );
  }

  factory FollowDetails.fromJson(Map<String, dynamic> json) {
    final alertJson = json['alert'];
    final victimJson = json['victim'];
    final victimLocationJson = json['victim_location'];
    final routeJson = json['route'];

    return FollowDetails(
      alert: EmergencyAlert.fromJson(
        alertJson is Map<String, dynamic> ? alertJson : <String, dynamic>{},
      ),
      victim: victimJson is Map<String, dynamic>
          ? VictimProfile.fromJson(victimJson)
          : null,
      victimLocation: PositionSnapshot.fromJson(
        victimLocationJson is Map<String, dynamic>
            ? victimLocationJson
            : <String, dynamic>{},
      ),
      route: routeJson is Map<String, dynamic>
          ? RouteSummary.fromJson(routeJson)
          : null,
    );
  }
}

class LocationPermissionResult {
  const LocationPermissionResult({
    required this.granted,
    this.status = GuardianLocationStatus.notRequested,
    this.message,
    this.snapshot,
  });

  final bool granted;
  final GuardianLocationStatus status;
  final String? message;
  final PositionSnapshot? snapshot;
}
