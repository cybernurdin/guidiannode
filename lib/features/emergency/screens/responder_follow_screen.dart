import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../services/device_location_service.dart';
import '../services/emergency_api_service.dart';
import '../services/google_maps_loader.dart';
import '../services/supabase_realtime_service.dart';
import '../utils/formatters.dart';
import '../utils/geo_utils.dart';
import '../utils/polyline_utils.dart';
import '../widgets/guardian_map_view.dart';

class ResponderFollowScreen extends StatefulWidget {
  const ResponderFollowScreen({
    super.key,
    required this.alertId,
    this.initialAlert,
  });

  final String alertId;
  final EmergencyAlert? initialAlert;

  @override
  State<ResponderFollowScreen> createState() => _ResponderFollowScreenState();
}

class _ResponderFollowScreenState extends State<ResponderFollowScreen> {
  late final Future<void> _mapsLoaderFuture;

  FollowDetails? _followDetails;
  PositionSnapshot? _responderPosition;
  RealtimeChannel? _alertLocationChannel;
  RealtimeChannel? _alertStatusChannel;
  StreamSubscription<PositionSnapshot>? _responderPositionSubscription;
  GuardianLocationStatus _locationStatus = GuardianLocationStatus.notRequested;

  bool _isInitializing = true;
  bool _isRefreshingRoute = false;
  bool _isSyncingResponse = false;
  bool _isUpdatingStatus = false;
  String? _blockingTitle;
  String? _blockingMessage;
  String? _syncWarning;
  String? _incidentStateMessage;
  String _responderStatus = 'on_the_way';
  DateTime? _lastRouteRefreshAt;
  PositionSnapshot? _lastRouteResponderPosition;
  PositionSnapshot? _lastRouteVictimPosition;

  @override
  void initState() {
    super.initState();
    _mapsLoaderFuture = GoogleMapsLoader.ensureLoaded();
    _followDetails = _localFollowDetails(widget.initialAlert);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(_responderPositionSubscription?.cancel());
    unawaited(
      SupabaseRealtimeService.instance.unsubscribe(_alertLocationChannel),
    );
    unawaited(
      SupabaseRealtimeService.instance.unsubscribe(_alertStatusChannel),
    );
    super.dispose();
  }

  Future<void> _initialize() async {
    final initialProblem = _initialAlertProblem();
    if (initialProblem != null) {
      _setBlockingState(initialProblem.title, initialProblem.message);
      return;
    }

    final permissionResult =
        await DeviceLocationService.requestCurrentSnapshot();

    if (!mounted) {
      return;
    }

    _locationStatus = permissionResult.status;

    if (!permissionResult.granted || permissionResult.snapshot == null) {
      setState(() {
        _isInitializing = false;
        _blockingTitle = 'Turn on location to start guidance.';
        _blockingMessage = _locationMessage(permissionResult);
      });
      return;
    }

    setState(() {
      _responderPosition = permissionResult.snapshot;
      _isInitializing = _followDetails == null;
      _blockingTitle = null;
      _blockingMessage = null;
    });

    _startResponderTracking();
    await _subscribeToRealtime();
    unawaited(_syncResponderStatus('on_the_way'));
    await _loadFollowDetails(forceRoute: true);
  }

  Future<void> _subscribeToRealtime() async {
    try {
      await SupabaseRealtimeService.instance.ensureInitialized();
    } catch (_) {
      return;
    }

    _alertLocationChannel = SupabaseRealtimeService.instance
        .subscribeToAlertLocation(
          alertId: widget.alertId,
          onChange: _handleVictimLocationChange,
        );
    _alertStatusChannel = SupabaseRealtimeService.instance
        .subscribeToAlertStatus(
          alertId: widget.alertId,
          onChange: _handleAlertStatusChange,
        );
  }

  void _handleVictimLocationChange(Map<String, dynamic> payload) {
    final followDetails = _followDetails;
    if (!mounted || followDetails == null) {
      return;
    }

    final payloadUserId = payload['user_id']?.toString();
    if (payloadUserId != null &&
        payloadUserId.isNotEmpty &&
        payloadUserId != followDetails.alert.userId) {
      return;
    }

    final victimPosition = PositionSnapshot.fromJson(payload);
    if (!_hasUsableCoordinates(
      victimPosition.latitude,
      victimPosition.longitude,
    )) {
      return;
    }

    final updatedAlert = followDetails.alert.copyWith(
      latitude: victimPosition.latitude,
      longitude: victimPosition.longitude,
      readableAddress:
          victimPosition.readableAddress ?? followDetails.alert.readableAddress,
      locality: victimPosition.locality ?? followDetails.alert.locality,
      updatedAt: victimPosition.capturedAt ?? followDetails.alert.updatedAt,
    );

    setState(() {
      _followDetails = followDetails.copyWith(
        alert: updatedAlert,
        victimLocation: victimPosition,
      );
    });

    if (_shouldRefreshRoute(
      responderPosition: _responderPosition,
      victimPosition: victimPosition,
    )) {
      unawaited(_loadFollowDetails(forceRoute: true));
    }
  }

  void _handleAlertStatusChange(Map<String, dynamic> payload) {
    final status = payload['status']?.toString();
    if (!mounted || status == null || status.trim().isEmpty) {
      return;
    }

    final resolvedAt = _parseDateTime(payload['resolved_at']);
    final updatedAt = _parseDateTime(payload['updated_at']);
    final followDetails = _followDetails;

    setState(() {
      if (followDetails != null) {
        _followDetails = followDetails.copyWith(
          alert: followDetails.alert.copyWith(
            status: status,
            updatedAt: updatedAt ?? followDetails.alert.updatedAt,
            resolvedAt: resolvedAt ?? followDetails.alert.resolvedAt,
          ),
        );
      }

      if (_isClosedAlertStatus(status)) {
        _incidentStateMessage = status.toLowerCase().contains('resolved')
            ? 'Incident resolved. You can stop following.'
            : 'Incident closed. Guidance has stopped.';
      }
    });

    if (_isClosedAlertStatus(status)) {
      unawaited(_responderPositionSubscription?.cancel());
      _responderPositionSubscription = null;
    }
  }

  void _startResponderTracking() {
    _responderPositionSubscription ??=
        DeviceLocationService.getPositionStream(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 15,
        ).listen(
          (position) {
            _responderPosition = position;
            if (mounted) {
              setState(() {});
            }

            final followDetails = _followDetails;
            if (followDetails != null &&
                _shouldRefreshRoute(
                  responderPosition: position,
                  victimPosition: followDetails.victimLocation,
                )) {
              unawaited(_loadFollowDetails(forceRoute: true));
            }
          },
          onError: (_) {
            if (mounted) {
              setState(() {
                _syncWarning =
                    'GPS is temporarily unavailable. Guidance will resume when your location updates.';
              });
            }
          },
        );
  }

  Future<void> _loadFollowDetails({required bool forceRoute}) async {
    final responderPosition = _responderPosition;
    if (responderPosition == null) {
      return;
    }

    setState(() {
      _isRefreshingRoute = forceRoute;
      if (_followDetails == null) {
        _isInitializing = true;
      }
    });

    try {
      final followDetails = await EmergencyApiService.fetchFollowDetails(
        alertId: widget.alertId,
        responderLocation: responderPosition,
      );

      if (!mounted) {
        return;
      }

      final hasVictimCoordinates = _hasUsableCoordinates(
        followDetails.victimLocation.latitude,
        followDetails.victimLocation.longitude,
      );

      if (!hasVictimCoordinates) {
        throw const ApiException(
          message: 'Alert location unavailable.',
          code: 'alert_location_missing',
        );
      }

      setState(() {
        _followDetails = followDetails;
        _isInitializing = false;
        _isRefreshingRoute = false;
        _lastRouteRefreshAt = DateTime.now();
        _lastRouteResponderPosition = responderPosition;
        _lastRouteVictimPosition = followDetails.victimLocation;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final hasLocalGuidance = _followDetails != null;
      setState(() {
        _isInitializing = false;
        _isRefreshingRoute = false;

        if (hasLocalGuidance) {
          _syncWarning = _guidanceWarning(error);
        } else {
          _blockingTitle = 'Alert location unavailable.';
          _blockingMessage =
              'GuardianNode could not load coordinates for this alert. Return to alerts and try again.';
        }
      });
    }
  }

  Future<void> _syncResponderStatus(
    String status, {
    bool showSuccess = false,
  }) async {
    final responderPosition = _responderPosition;
    if (_isSyncingResponse ||
        _isClosedAlertStatus(_followDetails?.alert.status ?? '')) {
      return;
    }

    setState(() {
      _isSyncingResponse = true;
      _responderStatus = status;
    });

    try {
      await EmergencyApiService.respondToAlert(
        alertId: widget.alertId,
        status: status,
        responderLocation: responderPosition,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _syncWarning = null;
      });

      if (showSuccess) {
        StatusSnackbar.show(
          context,
          message: status == 'arrived'
              ? 'Responder status updated: arrived.'
              : 'Responder status synced.',
          tone: StatusTone.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _syncWarning = _guidanceWarning(error);
      });

      if (showSuccess) {
        StatusSnackbar.show(
          context,
          message: 'Could not update responder status. Guidance still works.',
          tone: StatusTone.warning,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingResponse = false);
      }
    }
  }

  Future<void> _markArrived() async {
    setState(() => _isUpdatingStatus = true);
    await _syncResponderStatus('arrived', showSuccess: true);
    if (mounted) {
      setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _retryGuidance() async {
    if (_responderPosition == null) {
      await _retryLocation();
      return;
    }

    await _syncResponderStatus(_responderStatus);
    await _loadFollowDetails(forceRoute: true);
  }

  Future<void> _retryLocation() async {
    setState(() {
      _isInitializing = true;
      _blockingTitle = null;
      _blockingMessage = null;
    });
    await _initialize();
  }

  Future<void> _handleEnableLocation() async {
    if (_locationStatus == GuardianLocationStatus.serviceDisabled) {
      await DeviceLocationService.openLocationSettings();
    } else if (_locationStatus ==
        GuardianLocationStatus.permissionDeniedForever) {
      await DeviceLocationService.openAppSettings();
    }

    await _retryLocation();
  }

  Future<void> _openInGoogleMaps() async {
    final victimLocation = _followDetails?.victimLocation;
    if (victimLocation == null) {
      return;
    }

    final destination =
        '${victimLocation.latitude},${victimLocation.longitude}';
    final nativeUri = Uri.parse('google.navigation:q=$destination');
    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });

    try {
      if (await launchUrl(nativeUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Fall through to the universal web URL.
    }

    final opened = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      StatusSnackbar.show(
        context,
        message: 'Could not open Google Maps on this device.',
        tone: StatusTone.error,
      );
    }
  }

  bool _shouldRefreshRoute({
    required PositionSnapshot? responderPosition,
    required PositionSnapshot victimPosition,
  }) {
    if (responderPosition == null || _isRefreshingRoute) {
      return false;
    }

    if (_lastRouteRefreshAt == null ||
        DateTime.now().difference(_lastRouteRefreshAt!).inSeconds >= 20) {
      return true;
    }

    final responderMoved = _lastRouteResponderPosition == null
        ? true
        : distanceInMeters(_lastRouteResponderPosition!, responderPosition) >=
              30;
    final victimMoved = _lastRouteVictimPosition == null
        ? true
        : distanceInMeters(_lastRouteVictimPosition!, victimPosition) >= 30;

    return responderMoved || victimMoved;
  }

  @override
  Widget build(BuildContext context) {
    final followDetails = _followDetails;
    final responderPosition = _responderPosition;

    if (_blockingTitle != null) {
      return _buildBlockingState();
    }

    if (_isInitializing || followDetails == null || responderPosition == null) {
      return _buildLoadingState();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Responder Follow Mode'),
        actions: [
          IconButton(
            tooltip: 'Refresh route',
            onPressed: _isRefreshingRoute ? null : _retryGuidance,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _mapsLoaderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              title: 'Map unavailable',
              message: snapshot.error.toString(),
              onRetry: _retryGuidance,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GuardianMapView(
                  markers: _buildMarkers(followDetails),
                  polylines: _buildPolylines(followDetails),
                  focusPoints: [
                    responderPosition.latLng,
                    followDetails.victimLocation.latLng,
                  ],
                  initialCenter: responderPosition.latLng,
                  initialZoom: 15,
                  buildingsEnabled: true,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  trafficEnabled: true,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: _buildMapBanners(),
              ),
              if (_isRefreshingRoute)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildGuidanceSheet(followDetails),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Responder Follow Mode')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Getting your location...'),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockingState() {
    final isLocationIssue =
        _responderPosition == null &&
        (_locationStatus == GuardianLocationStatus.permissionDenied ||
            _locationStatus == GuardianLocationStatus.permissionDeniedForever ||
            _locationStatus == GuardianLocationStatus.serviceDisabled ||
            _locationStatus == GuardianLocationStatus.failed);
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Responder Follow Mode')),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: isLocationIssue
                      ? (isDark
                            ? const Color(0xFF112642)
                            : AppColors.trustBlueSurface)
                      : (isDark
                            ? const Color(0xFF3A1718)
                            : AppColors.errorSurface),
                  borderRadius: AppRadii.card,
                ),
                child: Icon(
                  isLocationIssue
                      ? Icons.location_searching_rounded
                      : Icons.location_off_rounded,
                  color: isLocationIssue
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.errorFor(context),
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _blockingTitle ?? 'Guidance unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _blockingMessage ??
                    'GuardianNode could not start route guidance for this alert.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isLocationIssue) ...[
                PrimaryButton(
                  text: 'Enable Location',
                  icon: Icons.my_location_rounded,
                  onPressed: _handleEnableLocation,
                ),
                if (_locationStatus ==
                    GuardianLocationStatus.permissionDeniedForever) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlineActionButton(
                    text: 'Open App Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () {
                      unawaited(DeviceLocationService.openAppSettings());
                    },
                  ),
                ],
              ] else
                PrimaryButton(
                  text: 'Back to Alerts',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlineActionButton(
                text: isLocationIssue ? 'Try Again' : 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: isLocationIssue ? _retryLocation : _retryGuidance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapBanners() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_incidentStateMessage != null)
          _ActionBanner(
            title: 'Incident resolved',
            message: _incidentStateMessage!,
            tone: StatusTone.success,
          ),
        if (_syncWarning != null) ...[
          if (_incidentStateMessage != null)
            const SizedBox(height: AppSpacing.sm),
          _ActionBanner(
            title: 'Guidance available',
            message: _syncWarning!,
            tone: StatusTone.warning,
            actionLabel: _isSyncingResponse ? 'Syncing' : 'Retry sync',
            onAction: _isSyncingResponse
                ? null
                : () => _syncResponderStatus(_responderStatus),
          ),
        ],
      ],
    );
  }

  Widget _buildGuidanceSheet(FollowDetails followDetails) {
    final routeWarning = _routeWarningForDetails(followDetails);
    final destinationLabel = _destinationLabel(followDetails);
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurfaceFor(context),
          borderRadius: AppRadii.sheet,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatEmergencyType(followDetails.alert.emergencyType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: _formatStatusLabel(_responderStatus),
                  tone: _responderStatus == 'arrived'
                      ? StatusTone.success
                      : StatusTone.action,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_rounded,
                  color: AppColors.engagementOrange,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    destinationLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _GuidanceMetric(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: _distanceLabel(followDetails),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _GuidanceMetric(
                    icon: Icons.schedule_rounded,
                    label: 'ETA',
                    value: _etaLabel(followDetails),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _GuidanceMetric(
                    icon: Icons.update_rounded,
                    label: 'Updated',
                    value: formatRelativeTime(
                      followDetails.victimLocation.capturedAt ??
                          followDetails.alert.updatedAt,
                    ),
                  ),
                ),
              ],
            ),
            if (routeWarning != null) ...[
              const SizedBox(height: AppSpacing.md),
              _InlineNotice(
                icon: Icons.navigation_rounded,
                message: routeWarning,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const _InlineNotice(
              icon: Icons.health_and_safety_rounded,
              message:
                  'Approach carefully. Call emergency services if the scene is unsafe.',
              tone: StatusTone.info,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Open in Google Maps',
                    icon: Icons.map_rounded,
                    onPressed: _openInGoogleMaps,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlineActionButton(
                    text: 'Arrived',
                    icon: Icons.flag_rounded,
                    onPressed: _isUpdatingStatus ? null : _markArrived,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(FollowDetails followDetails) {
    final responderPosition = _responderPosition;
    if (responderPosition == null) {
      return const <Marker>{};
    }

    return {
      Marker(
        markerId: const MarkerId('responder'),
        position: responderPosition.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        zIndexInt: 5,
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
      Marker(
        markerId: const MarkerId('victim'),
        position: followDetails.victimLocation.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        zIndexInt: 6,
        infoWindow: InfoWindow(
          title: 'Alert location',
          snippet: formatEmergencyType(followDetails.alert.emergencyType),
        ),
      ),
    };
  }

  Set<Polyline> _buildPolylines(FollowDetails followDetails) {
    final route = followDetails.route;
    final routePoints = decodeEncodedPolyline(route?.encodedPolyline);

    if (routePoints.length >= 2) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          width: 6,
          color: AppColors.trustBlue,
        ),
      };
    }

    final responderPosition = _responderPosition;
    if (responderPosition == null) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('direct-alert-line'),
        points: [responderPosition.latLng, followDetails.victimLocation.latLng],
        width: 4,
        color: AppColors.engagementOrange,
      ),
    };
  }

  String _distanceLabel(FollowDetails followDetails) {
    final route = followDetails.route;
    if (route != null && route.distanceMeters > 0) {
      return route.distanceText;
    }

    final responderPosition = _responderPosition;
    if (responderPosition == null) {
      return '--';
    }

    return formatDistance(
      distanceInMeters(responderPosition, followDetails.victimLocation),
    );
  }

  String _etaLabel(FollowDetails followDetails) {
    final route = followDetails.route;
    if (route != null && route.durationSeconds > 0) {
      return route.durationText;
    }

    return '--';
  }

  String _destinationLabel(FollowDetails followDetails) {
    final alertAddress = followDetails.alert.displayAddress;
    if (alertAddress != 'Location unavailable') {
      return alertAddress;
    }

    final victimAddress = followDetails.victimLocation.displayAddress;
    if (victimAddress != 'Location ready') {
      return victimAddress;
    }

    return _formatCoordinates(followDetails.victimLocation);
  }

  String? _routeWarningForDetails(FollowDetails? followDetails) {
    if (followDetails == null) {
      return null;
    }

    final routePoints = decodeEncodedPolyline(
      followDetails.route?.encodedPolyline,
    );
    return routePoints.length >= 2
        ? null
        : 'Route unavailable. Follow the alert marker.';
  }

  String _guidanceWarning(Object error) {
    if (error is ApiException) {
      if (error.code == 'no_internet') {
        return 'You appear offline. Guidance will continue if location data is available.';
      }

      if (error.code == 'request_timeout') {
        return 'Could not sync response before timeout. Guidance still available.';
      }
    }

    return 'Could not sync response. Guidance still available.';
  }

  String _locationMessage(LocationPermissionResult result) {
    return switch (result.status) {
      GuardianLocationStatus.serviceDisabled =>
        'Turn on location services to show your current position and route.',
      GuardianLocationStatus.permissionDenied =>
        'Location permission is needed to start responder guidance.',
      GuardianLocationStatus.permissionDeniedForever =>
        'Location permission is disabled. Open app settings to enable guidance.',
      _ => result.message ?? 'GPS is temporarily unavailable. Try again.',
    };
  }

  _InitialProblem? _initialAlertProblem() {
    if (widget.alertId.trim().isEmpty) {
      return const _InitialProblem(
        title: 'Alert location unavailable.',
        message: 'This alert is missing the required alert ID.',
      );
    }

    final initialAlert = widget.initialAlert;
    if (initialAlert != null && _isClosedAlertStatus(initialAlert.status)) {
      return const _InitialProblem(
        title: 'Incident resolved',
        message: 'This alert is no longer active.',
      );
    }

    return null;
  }

  void _setBlockingState(String title, String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = false;
      _blockingTitle = title;
      _blockingMessage = message;
    });
  }

  FollowDetails? _localFollowDetails(EmergencyAlert? alert) {
    if (alert == null ||
        !_hasUsableCoordinates(alert.latitude, alert.longitude)) {
      return null;
    }

    return FollowDetails(
      alert: alert,
      victim: alert.victim,
      victimLocation: PositionSnapshot(
        latitude: alert.latitude,
        longitude: alert.longitude,
        readableAddress: alert.readableAddress,
        locality: alert.locality,
        capturedAt: alert.updatedAt ?? alert.createdAt,
      ),
    );
  }

  bool _hasUsableCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude.abs() < 0.000001 && longitude.abs() < 0.000001);
  }

  bool _isClosedAlertStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('resolved') ||
        normalized.contains('cancelled') ||
        normalized.contains('canceled') ||
        normalized.contains('closed') ||
        normalized.contains('safe');
  }

  String _formatCoordinates(PositionSnapshot position) {
    return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }

  String _formatStatusLabel(String status) {
    return status
        .split(RegExp(r'[_\s-]+'))
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

class _InitialProblem {
  const _InitialProblem({required this.title, required this.message});

  final String title;
  final String message;
}

class _GuidanceMetric extends StatelessWidget {
  const _GuidanceMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMutedFor(context),
        borderRadius: AppRadii.card,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.trustBlue, size: 18),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    this.tone = StatusTone.warning,
  });

  final IconData icon;
  final String message;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final foreground = _foregroundForTone(tone, isDark: isDark);
    final background = _backgroundForTone(tone, isDark: isDark);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.card,
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.title,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final StatusTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final foreground = _foregroundForTone(tone, isDark: isDark);
    final background = _backgroundForTone(tone, isDark: isDark);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.card,
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForTone(tone), color: foreground, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Color _foregroundForTone(StatusTone tone, {required bool isDark}) {
  if (isDark) {
    return switch (tone) {
      StatusTone.success => const Color(0xFF34D399),
      StatusTone.warning => AppColors.communityYellow,
      StatusTone.error => AppColors.darkError,
      StatusTone.info => const Color(0xFF8DB7FF),
      StatusTone.action => const Color(0xFFFFB59B),
    };
  }

  return switch (tone) {
    StatusTone.success => AppColors.safetyGreen,
    StatusTone.warning => const Color(0xFF8A5A00),
    StatusTone.error => AppColors.error,
    StatusTone.info => AppColors.trustBlue,
    StatusTone.action => AppColors.engagementOrange,
  };
}

Color _backgroundForTone(StatusTone tone, {required bool isDark}) {
  if (isDark) {
    return switch (tone) {
      StatusTone.success => const Color(0xFF0F2D24),
      StatusTone.warning => const Color(0xFF332B12),
      StatusTone.error => const Color(0xFF3A1718),
      StatusTone.info => const Color(0xFF112642),
      StatusTone.action => const Color(0xFF3A2118),
    };
  }

  return switch (tone) {
    StatusTone.success => AppColors.safetyGreenSurface,
    StatusTone.warning => AppColors.communityYellowSurface,
    StatusTone.error => AppColors.errorSurface,
    StatusTone.info => AppColors.trustBlueSurface,
    StatusTone.action => AppColors.engagementOrangeSurface,
  };
}

IconData _iconForTone(StatusTone tone) {
  return switch (tone) {
    StatusTone.success => Icons.check_circle_outline_rounded,
    StatusTone.warning => Icons.warning_amber_rounded,
    StatusTone.error => Icons.error_outline_rounded,
    StatusTone.info => Icons.info_outline_rounded,
    StatusTone.action => Icons.notifications_active_outlined,
  };
}
