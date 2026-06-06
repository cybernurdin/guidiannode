import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/guardian_components.dart';
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
  StreamSubscription<PositionSnapshot>? _responderPositionSubscription;
  bool _isLoading = true;
  bool _isRefreshingRoute = false;
  String? _error;
  DateTime? _lastRouteRefreshAt;
  PositionSnapshot? _lastRouteResponderPosition;
  PositionSnapshot? _lastRouteVictimPosition;

  @override
  void initState() {
    super.initState();
    _mapsLoaderFuture = GoogleMapsLoader.ensureLoaded();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(_responderPositionSubscription?.cancel());
    unawaited(
      SupabaseRealtimeService.instance.unsubscribe(_alertLocationChannel),
    );
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final permissionResult =
          await DeviceLocationService.requestCurrentSnapshot();

      if (!permissionResult.granted || permissionResult.snapshot == null) {
        throw Exception(
          permissionResult.message ??
              'Location permission is required before you can follow a victim.',
        );
      }

      _responderPosition = permissionResult.snapshot;
      await _loadFollowDetails(forceRoute: true);
      await _subscribeToLocationUpdates();
      _startResponderTracking();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _subscribeToLocationUpdates() async {
    try {
      await SupabaseRealtimeService.instance.ensureInitialized();
    } catch (_) {
      return;
    }

    _alertLocationChannel = SupabaseRealtimeService.instance
        .subscribeToAlertLocation(
          alertId: widget.alertId,
          onChange: (payload) {
            if (!mounted || _followDetails == null) {
              return;
            }

            final victimPosition = PositionSnapshot.fromJson(payload);
            final updatedAlert = _followDetails!.alert.copyWith(
              latitude: victimPosition.latitude,
              longitude: victimPosition.longitude,
              readableAddress:
                  victimPosition.readableAddress ??
                  _followDetails!.alert.readableAddress,
              locality:
                  victimPosition.locality ?? _followDetails!.alert.locality,
              updatedAt:
                  victimPosition.capturedAt ?? _followDetails!.alert.updatedAt,
            );

            setState(() {
              _followDetails = _followDetails!.copyWith(
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
          },
        );
  }

  void _startResponderTracking() {
    _responderPositionSubscription =
        DeviceLocationService.getPositionStream(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 15,
        ).listen((position) {
          _responderPosition = position;
          if (mounted) {
            setState(() {});
          }

          if (_followDetails != null &&
              _shouldRefreshRoute(
                responderPosition: position,
                victimPosition: _followDetails!.victimLocation,
              )) {
            unawaited(_loadFollowDetails(forceRoute: true));
          }
        });
  }

  Future<void> _loadFollowDetails({required bool forceRoute}) async {
    final responderPosition = _responderPosition;
    if (responderPosition == null) {
      return;
    }

    setState(() {
      if (_followDetails == null) {
        _isLoading = true;
      }
      _isRefreshingRoute = forceRoute;
      _error = null;
    });

    try {
      final followDetails = await EmergencyApiService.fetchFollowDetails(
        alertId: widget.alertId,
        responderLocation: responderPosition,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _followDetails = followDetails;
        _isLoading = false;
        _isRefreshingRoute = false;
        _lastRouteRefreshAt = DateTime.now();
        _lastRouteResponderPosition = responderPosition;
        _lastRouteVictimPosition = followDetails.victimLocation;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshingRoute = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  bool _shouldRefreshRoute({
    required PositionSnapshot? responderPosition,
    required PositionSnapshot victimPosition,
  }) {
    if (responderPosition == null) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Responder follow mode')),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ErrorState(
                  title: 'Follow mode unavailable',
                  message: _error!,
                  onRetry: () => _loadFollowDetails(forceRoute: true),
                )
              : followDetails == null || _responderPosition == null
              ? const EmptyState(
                  title: 'Follow details missing',
                  message:
                      'GuardianNode could not load live responder guidance for this alert.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.cleanWhite,
                        borderRadius: AppRadii.card,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: AppColors.engagementOrange.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: AppColors.engagementOrange,
                              size: 46,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Help is on the way!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Stay calm and stay safe.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AlertDetailsCard(
                      title: formatEmergencyType(
                        followDetails.alert.emergencyType,
                      ),
                      rows: {
                        'ETA': followDetails.route?.durationText ?? '--',
                        'Distance': followDetails.route?.distanceText ?? '--',
                        'Updated': formatRelativeTime(
                          followDetails.victimLocation.capturedAt,
                        ),
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.card,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          AlertProgressStep(
                            label: 'Alert Sent',
                            status: 'Done',
                            tone: StatusTone.success,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          AlertProgressStep(
                            label: 'Accepted',
                            status: 'Done',
                            tone: StatusTone.success,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          AlertProgressStep(
                            label: 'On the way',
                            status: 'Live',
                            tone: StatusTone.action,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          AlertProgressStep(
                            label: 'Arrived',
                            status: 'Pending',
                            tone: StatusTone.warning,
                          ),
                        ],
                      ),
                    ),
                    if (_isRefreshingRoute) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: FutureBuilder<void>(
                        future: _mapsLoaderFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return ErrorState(
                              title: 'Map unavailable',
                              message: snapshot.error.toString(),
                            );
                          }

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: GuardianMapView(
                                  markers: _buildMarkers(followDetails),
                                  polylines: _buildPolylines(followDetails),
                                  focusPoints: [
                                    _responderPosition!.latLng,
                                    followDetails.victimLocation.latLng,
                                  ],
                                  initialCenter:
                                      followDetails.victimLocation.latLng,
                                ),
                              ),
                              Positioned(
                                left: AppSpacing.md,
                                right: AppSpacing.md,
                                bottom: AppSpacing.md,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.cleanWhite.withValues(
                                      alpha: 0.96,
                                    ),
                                    borderRadius: AppRadii.card,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Victim location updates and route guidance are live.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(FollowDetails followDetails) {
    return {
      Marker(
        markerId: const MarkerId('responder'),
        position: _responderPosition!.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('victim'),
        position: followDetails.victimLocation.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Set<Polyline> _buildPolylines(FollowDetails followDetails) {
    final route = followDetails.route;
    if (route?.encodedPolyline == null || route!.encodedPolyline!.isEmpty) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: decodeEncodedPolyline(route.encodedPolyline),
        width: 5,
        color: AppColors.trustBlue,
      ),
    };
  }
}
