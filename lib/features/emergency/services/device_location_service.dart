import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/emergency_models.dart';

class DeviceLocationService {
  static Future<LocationPermissionResult> requestCurrentSnapshot() async {
    final isLocationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!isLocationServiceEnabled) {
      return const LocationPermissionResult(
        granted: false,
        status: GuardianLocationStatus.serviceDisabled,
        message: 'Turn on location services',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationPermissionResult(
        granted: false,
        status: GuardianLocationStatus.permissionDenied,
        message: 'Location permission needed',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionResult(
        granted: false,
        status: GuardianLocationStatus.permissionDeniedForever,
        message: 'Location permission disabled. Open settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return LocationPermissionResult(
        granted: true,
        status: GuardianLocationStatus.ready,
        snapshot: PositionSnapshot.fromPosition(position),
      );
    } on TimeoutException {
      return _lastKnownOrFailure();
    } catch (_) {
      return _lastKnownOrFailure();
    }
  }

  static Future<LocationPermissionResult> _lastKnownOrFailure() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return LocationPermissionResult(
          granted: true,
          status: GuardianLocationStatus.usingLastKnown,
          message: 'Using last known location',
          snapshot: PositionSnapshot.fromPosition(lastKnown),
        );
      }
    } catch (_) {
      // The friendly failure below is enough for the user to recover.
    }

    return const LocationPermissionResult(
      granted: false,
      status: GuardianLocationStatus.failed,
      message: 'Could not get location. Tap to retry.',
    );
  }

  static Future<LocationPermissionResult> checkLocationStatus() async {
    final isLocationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!isLocationServiceEnabled) {
      return const LocationPermissionResult(
        granted: false,
        status: GuardianLocationStatus.serviceDisabled,
        message: 'Turn on location services',
      );
    }

    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      return const LocationPermissionResult(
        granted: false,
        status: GuardianLocationStatus.permissionDenied,
        message: 'Location permission needed',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionResult(
        granted: false,
        status: GuardianLocationStatus.permissionDeniedForever,
        message: 'Location permission disabled. Open settings.',
      );
    }

    return const LocationPermissionResult(
      granted: true,
      status: GuardianLocationStatus.ready,
    );
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  static Stream<PositionSnapshot> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).map(PositionSnapshot.fromPosition);
  }
}
