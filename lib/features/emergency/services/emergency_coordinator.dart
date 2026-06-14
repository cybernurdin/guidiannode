import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/api_client.dart';
import '../models/emergency_models.dart';
import '../utils/geo_utils.dart';
import 'device_location_service.dart';
import 'emergency_api_service.dart';

class EmergencyCoordinator extends ChangeNotifier {
  EmergencyCoordinator._();

  static final EmergencyCoordinator instance = EmergencyCoordinator._();

  bool _locationSharingEnabled = false;
  bool _isUpdatingLocationSharing = false;
  bool _isTriggeringSos = false;
  String? _locationError;
  GuardianLocationStatus _locationStatus = GuardianLocationStatus.notRequested;
  EmergencyAlert? _activeAlert;
  PositionSnapshot? _currentPosition;
  StreamSubscription<PositionSnapshot>? _positionSubscription;
  PositionSnapshot? _lastPassiveSyncedPosition;
  DateTime? _lastPassiveSyncAt;
  PositionSnapshot? _lastAlertSyncedPosition;
  DateTime? _lastAlertSyncAt;
  bool _passiveSyncInFlight = false;
  bool _alertSyncInFlight = false;
  String? _initializedUserId;

  bool get locationSharingEnabled => _locationSharingEnabled;
  bool get isUpdatingLocationSharing => _isUpdatingLocationSharing;
  bool get isTriggeringSos => _isTriggeringSos;
  String? get locationError => _locationError;
  GuardianLocationStatus get locationStatus => _locationStatus;
  EmergencyAlert? get activeAlert => _activeAlert;
  PositionSnapshot? get currentPosition => _currentPosition;

  Future<void> initializeFromSession() async {
    final user = SessionService.currentUser;
    final userId = user?['id']?.toString();

    if (userId == null || userId.isEmpty || _initializedUserId == userId) {
      return;
    }

    _initializedUserId = userId;
    _locationSharingEnabled = user?['location_permission'] == true;
    final latitude = _toDouble(user?['latitude']);
    final longitude = _toDouble(user?['longitude']);

    if (latitude != null && longitude != null) {
      _currentPosition = PositionSnapshot(
        latitude: latitude,
        longitude: longitude,
      );
      _locationStatus = GuardianLocationStatus.usingLastKnown;
    }

    if (_locationSharingEnabled) {
      final checkResult = await DeviceLocationService.checkLocationStatus();
      if (!checkResult.granted) {
        _locationStatus = checkResult.status;
        _locationError = checkResult.message;
        notifyListeners();
        return;
      }

      await _ensurePositionStream();

      _locationStatus = _currentPosition == null
          ? GuardianLocationStatus.fetching
          : GuardianLocationStatus.usingLastKnown;
      notifyListeners();

      final permissionResult =
          await DeviceLocationService.requestCurrentSnapshot();

      if (permissionResult.snapshot != null) {
        _currentPosition = permissionResult.snapshot;
        _locationStatus = permissionResult.status;
        _locationError = null;
        await _syncPassiveLocation(permissionResult.snapshot!, force: true);
      } else {
        if (_currentPosition == null) {
          _locationStatus = permissionResult.status;
          _locationError = permissionResult.message;
        }
      }
    }

    notifyListeners();
  }

  Future<void> checkAndUpdateLocationStatus() async {
    final checkResult = await DeviceLocationService.checkLocationStatus();

    if (!checkResult.granted) {
      _locationStatus = checkResult.status;
      _locationError = checkResult.message;
      await _stopPositionStream();
      notifyListeners();
      return;
    }

    if (_locationSharingEnabled) {
      await _ensurePositionStream();

      if (_locationStatus == GuardianLocationStatus.serviceDisabled ||
          _locationStatus == GuardianLocationStatus.permissionDenied ||
          _locationStatus == GuardianLocationStatus.permissionDeniedForever ||
          _locationStatus == GuardianLocationStatus.failed ||
          _locationStatus == GuardianLocationStatus.notRequested) {
        _locationStatus = _currentPosition == null
            ? GuardianLocationStatus.fetching
            : GuardianLocationStatus.usingLastKnown;
        _locationError = null;
        notifyListeners();

        final permissionResult =
            await DeviceLocationService.requestCurrentSnapshot();
        if (permissionResult.snapshot != null) {
          _currentPosition = permissionResult.snapshot;
          _locationStatus = permissionResult.status;
          _locationError = null;
          await _syncPassiveLocation(permissionResult.snapshot!, force: true);
        } else {
          if (_currentPosition == null) {
            _locationStatus = permissionResult.status;
            _locationError = permissionResult.message;
          }
        }
        notifyListeners();
      }
    } else {
      if (_locationStatus == GuardianLocationStatus.permissionDenied ||
          _locationStatus == GuardianLocationStatus.permissionDeniedForever ||
          _locationStatus == GuardianLocationStatus.serviceDisabled ||
          _locationStatus == GuardianLocationStatus.failed) {
        _locationStatus = GuardianLocationStatus.notRequested;
        _locationError = null;
        notifyListeners();
      }
    }
  }

  Future<LocationPermissionResult> previewLocationPermission(
    bool enabled,
  ) async {
    if (!enabled) {
      _locationError = null;
      _locationStatus = GuardianLocationStatus.notRequested;
      notifyListeners();
      return const LocationPermissionResult(granted: false);
    }

    _locationStatus = GuardianLocationStatus.fetching;
    notifyListeners();
    final permissionResult =
        await DeviceLocationService.requestCurrentSnapshot();

    if (permissionResult.snapshot != null) {
      _currentPosition = permissionResult.snapshot;
    }

    _locationStatus = permissionResult.status;
    _locationError = permissionResult.message;
    notifyListeners();
    return permissionResult;
  }

  Future<bool> setLocationSharingEnabled(bool enabled) async {
    _isUpdatingLocationSharing = true;
    notifyListeners();

    try {
      if (!enabled) {
        await EmergencyApiService.updateUserLocation(locationPermission: false);
        _locationSharingEnabled = false;
        _locationStatus = GuardianLocationStatus.notRequested;
        _locationError = null;
        SessionService.updateCurrentUserFields({
          'location_permission': false,
          'latitude': null,
          'longitude': null,
        });

        if (_activeAlert == null) {
          await _stopPositionStream();
        }

        return true;
      }

      _locationStatus = GuardianLocationStatus.fetching;
      notifyListeners();
      final permissionResult =
          await DeviceLocationService.requestCurrentSnapshot();

      if (!permissionResult.granted || permissionResult.snapshot == null) {
        _locationStatus = permissionResult.status;
        _locationError = permissionResult.message;
        return false;
      }

      _locationSharingEnabled = true;
      _currentPosition = permissionResult.snapshot;
      _locationStatus = permissionResult.status;
      _locationError = null;
      await _ensurePositionStream();
      await _syncPassiveLocation(permissionResult.snapshot!, force: true);

      return true;
    } finally {
      _isUpdatingLocationSharing = false;
      notifyListeners();
    }
  }

  Future<PositionSnapshot?> refreshCurrentPosition() async {
    _locationStatus = GuardianLocationStatus.fetching;
    _locationError = null;
    notifyListeners();
    final permissionResult =
        await DeviceLocationService.requestCurrentSnapshot();

    if (permissionResult.snapshot != null) {
      _currentPosition = permissionResult.snapshot;
      _locationStatus = permissionResult.status;
      _locationError = null;
      notifyListeners();
      return permissionResult.snapshot;
    }

    _locationStatus = permissionResult.status;
    _locationError = permissionResult.message;
    notifyListeners();
    return null;
  }

  Future<EmergencyAlert> triggerSos({
    required String emergencyType,
    String description = '',
  }) async {
    _isTriggeringSos = true;
    notifyListeners();

    try {
      var snapshot = _currentPosition;

      snapshot ??= await refreshCurrentPosition();

      if (snapshot == null) {
        throw ApiException(
          message:
              _locationError ??
              'Location is required before GuardianNode can send your SOS.',
          code: 'location_required',
        );
      }

      await _ensurePositionStream();
      final alert = await EmergencyApiService.createSosAlert(
        emergencyType: emergencyType,
        snapshot: snapshot,
        description: description,
      );
      _activeAlert = alert;
      _locationSharingEnabled = true;
      SessionService.updateCurrentUserFields({
        'location_permission': true,
        'latitude': snapshot.latitude,
        'longitude': snapshot.longitude,
      });
      _lastAlertSyncedPosition = snapshot;
      _lastAlertSyncAt = DateTime.now();

      return alert;
    } finally {
      _isTriggeringSos = false;
      notifyListeners();
    }
  }

  Future<EmergencyAlert?> resolveActiveSos() async {
    final alert = _activeAlert;

    if (alert == null) {
      return null;
    }

    final resolvedAlert = await EmergencyApiService.resolveAlert(
      alertId: alert.id,
    );
    _activeAlert = null;
    _lastAlertSyncedPosition = null;
    _lastAlertSyncAt = null;

    if (!_locationSharingEnabled) {
      await _stopPositionStream();
    }

    notifyListeners();
    return resolvedAlert;
  }

  Future<void> _ensurePositionStream() async {
    if (_positionSubscription != null) {
      return;
    }

    _positionSubscription =
        DeviceLocationService.getPositionStream(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ).listen(
          (snapshot) {
            _currentPosition = snapshot;
            _locationStatus = GuardianLocationStatus.ready;
            _locationError = null;
            notifyListeners();
            unawaited(_handlePositionSnapshot(snapshot));
          },
          onError: (Object error) {
            _locationStatus = GuardianLocationStatus.failed;
            _locationError = 'Could not get location. Tap to retry.';
            notifyListeners();
          },
        );
  }

  Future<void> _stopPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<bool> openAppSettings() => DeviceLocationService.openAppSettings();

  Future<bool> openLocationSettings() =>
      DeviceLocationService.openLocationSettings();

  Future<void> resetForSignOut() async {
    await _stopPositionStream();
    _locationSharingEnabled = false;
    _isUpdatingLocationSharing = false;
    _isTriggeringSos = false;
    _locationError = null;
    _locationStatus = GuardianLocationStatus.notRequested;
    _activeAlert = null;
    _currentPosition = null;
    _lastPassiveSyncedPosition = null;
    _lastPassiveSyncAt = null;
    _lastAlertSyncedPosition = null;
    _lastAlertSyncAt = null;
    _initializedUserId = null;
    notifyListeners();
  }

  Future<void> _handlePositionSnapshot(PositionSnapshot snapshot) async {
    if (_activeAlert != null) {
      await _syncAlertLocation(snapshot);
    }

    if (_locationSharingEnabled) {
      await _syncPassiveLocation(snapshot);
    }
  }

  Future<void> _syncPassiveLocation(
    PositionSnapshot snapshot, {
    bool force = false,
  }) async {
    if (!_locationSharingEnabled || _passiveSyncInFlight) {
      return;
    }

    if (!force &&
        !_shouldSync(
          snapshot,
          previousSnapshot: _lastPassiveSyncedPosition,
          previousSyncAt: _lastPassiveSyncAt,
          minimumDistanceMeters: 50,
          minimumInterval: const Duration(seconds: 30),
        )) {
      return;
    }

    _passiveSyncInFlight = true;

    try {
      await EmergencyApiService.updateUserLocation(
        locationPermission: true,
        snapshot: snapshot,
      );
      _lastPassiveSyncedPosition = snapshot;
      _lastPassiveSyncAt = DateTime.now();
      SessionService.updateCurrentUserFields({
        'location_permission': true,
        'latitude': snapshot.latitude,
        'longitude': snapshot.longitude,
      });
    } finally {
      _passiveSyncInFlight = false;
    }
  }

  Future<void> _syncAlertLocation(
    PositionSnapshot snapshot, {
    bool force = false,
  }) async {
    final alert = _activeAlert;

    if (alert == null || _alertSyncInFlight) {
      return;
    }

    if (!force &&
        !_shouldSync(
          snapshot,
          previousSnapshot: _lastAlertSyncedPosition,
          previousSyncAt: _lastAlertSyncAt,
          minimumDistanceMeters: 20,
          minimumInterval: const Duration(seconds: 6),
        )) {
      return;
    }

    _alertSyncInFlight = true;

    try {
      final liveLocation = await EmergencyApiService.updateAlertLocation(
        alertId: alert.id,
        snapshot: snapshot,
      );

      if (!liveLocation.skipped) {
        _lastAlertSyncedPosition = snapshot;
        _lastAlertSyncAt = DateTime.now();
        _activeAlert = alert.copyWith(
          latitude: liveLocation.latitude,
          longitude: liveLocation.longitude,
          readableAddress:
              liveLocation.readableAddress ?? alert.readableAddress,
          locality: liveLocation.locality ?? alert.locality,
          updatedAt: liveLocation.capturedAt ?? DateTime.now(),
        );
        notifyListeners();
      }
    } finally {
      _alertSyncInFlight = false;
    }
  }

  bool _shouldSync(
    PositionSnapshot snapshot, {
    required PositionSnapshot? previousSnapshot,
    required DateTime? previousSyncAt,
    required double minimumDistanceMeters,
    required Duration minimumInterval,
  }) {
    if (previousSnapshot == null || previousSyncAt == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(previousSyncAt);
    final movedDistance = distanceInMeters(previousSnapshot, snapshot);

    return elapsed >= minimumInterval || movedDistance >= minimumDistanceMeters;
  }
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
