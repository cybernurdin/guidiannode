import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../profile/screens/profile_screen.dart';
import '../models/emergency_models.dart';
import '../services/emergency_api_service.dart';
import '../services/emergency_coordinator.dart';
import '../services/google_maps_loader.dart';
import '../services/supabase_realtime_service.dart';
import '../widgets/dashboard_alerts_tab.dart';
import '../widgets/dashboard_community_tab.dart';
import '../widgets/dashboard_home_tab.dart';
import '../widgets/dashboard_map_tab.dart';
import '../widgets/dashboard_sheets.dart';
import '../../../core/widgets/guardian_components.dart';
import 'active_sos_map_screen.dart';
import 'responder_follow_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.bootstrapLocationSharing = false});

  final bool bootstrapLocationSharing;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final EmergencyCoordinator _coordinator = EmergencyCoordinator.instance;
  late final Future<void> _mapsLoaderFuture;

  int _currentIndex = 0;
  bool _isLoadingAlerts = false;
  String? _alertsError;
  List<EmergencyAlert> _nearbyAlerts = const <EmergencyAlert>[];
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _emergencyFeedChannel;
  bool _attemptedBootstrapLocationSharing = false;

  @override
  void initState() {
    super.initState();
    _mapsLoaderFuture = GoogleMapsLoader.ensureLoaded();
    _coordinator.addListener(_handleCoordinatorUpdated);
    unawaited(_initializeDashboard());
  }

  @override
  void dispose() {
    _coordinator.removeListener(_handleCoordinatorUpdated);
    unawaited(
      SupabaseRealtimeService.instance.unsubscribe(_notificationsChannel),
    );
    unawaited(
      SupabaseRealtimeService.instance.unsubscribe(_emergencyFeedChannel),
    );
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    await _coordinator.initializeFromSession();

    if (widget.bootstrapLocationSharing &&
        !_attemptedBootstrapLocationSharing &&
        !_coordinator.locationSharingEnabled) {
      _attemptedBootstrapLocationSharing = true;
      final enabled = await _coordinator.setLocationSharingEnabled(true);

      if (mounted && !enabled) {
        StatusSnackbar.show(
          context,
          message:
              _coordinator.locationError ??
              'Location permission is required to enable emergency routing.',
          tone: StatusTone.error,
        );
      }
    }

    await _refreshNearbyAlerts();
    await _subscribeToRealtime();
  }

  Future<void> _subscribeToRealtime() async {
    final userId = SessionService.currentUser?['id']?.toString();
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await SupabaseRealtimeService.instance.ensureInitialized();
    } catch (_) {
      return;
    }

    _notificationsChannel = SupabaseRealtimeService.instance
        .subscribeToUserNotifications(
          userId: userId,
          onInsert: (payload) {
            if (!mounted) {
              return;
            }

            if (AppPreferences.showCommunityBanners) {
              StatusSnackbar.show(
                context,
                message:
                    payload['title']?.toString() ??
                    'New nearby emergency alert.',
                tone: StatusTone.action,
              );
            }
            unawaited(_refreshNearbyAlerts(silent: true));
          },
        );

    _emergencyFeedChannel = SupabaseRealtimeService.instance
        .subscribeToEmergencyFeed(
          onMutation: () {
            if (mounted) {
              unawaited(_refreshNearbyAlerts(silent: true));
            }
          },
        );
  }

  void _handleCoordinatorUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshNearbyAlerts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingAlerts = true;
        _alertsError = null;
      });
    }

    try {
      final center =
          _coordinator.currentPosition ??
          await _coordinator.refreshCurrentPosition();

      if (center == null) {
        if (!silent) {
          setState(() {
            _isLoadingAlerts = false;
            _alertsError =
                _coordinator.locationError ??
                'Enable location sharing to fetch nearby alerts.';
          });
        }
        return;
      }

      final alerts = await EmergencyApiService.fetchNearbyAlerts(
        center: center,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nearbyAlerts = alerts;
        _isLoadingAlerts = false;
        _alertsError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingAlerts = false;
        _alertsError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleLocationSharingChanged(bool enabled) async {
    final success = await _coordinator.setLocationSharingEnabled(enabled);

    if (!mounted) {
      return;
    }

    if (!success && enabled) {
      StatusSnackbar.show(
        context,
        message:
            _coordinator.locationError ??
            'GuardianNode could not enable location sharing.',
        tone: StatusTone.error,
      );
      return;
    }

    StatusSnackbar.show(
      context,
      message: enabled
          ? 'Location sharing enabled.'
          : 'Location sharing turned off.',
      tone: enabled ? StatusTone.success : StatusTone.warning,
    );
    await _refreshNearbyAlerts(silent: true);
  }

  Future<void> _triggerSos(String emergencyType, {String? description}) async {
    if (_coordinator.activeAlert != null) {
      _openActiveSosScreen();
      return;
    }

    try {
      await _coordinator.triggerSos(
        emergencyType: emergencyType,
        description: description ?? 'Emergency raised from GuardianNode',
      );

      if (!mounted) {
        return;
      }

      StatusSnackbar.show(
        context,
        message: 'SOS sent. Nearby GuardianNode users are being notified now.',
        tone: StatusTone.error,
      );
      await _refreshNearbyAlerts(silent: true);
      _openActiveSosScreen();
    } catch (error) {
      if (!mounted) {
        return;
      }

      StatusSnackbar.show(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        tone: StatusTone.error,
      );
    }
  }

  void _openActiveSosScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ActiveSosMapScreen()));
  }

  void _openFollowScreen(EmergencyAlert alert) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResponderFollowScreen(alertId: alert.id, initialAlert: alert),
      ),
    );
  }

  void _openProfileScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
  }

  void _handleBottomNavigation(int index) {
    if (index == 4) {
      _openProfileScreen();
      return;
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardHomeTab(
            coordinator: _coordinator,
            nearbyAlerts: _nearbyAlerts,
            isLoadingAlerts: _isLoadingAlerts,
            alertsError: _alertsError,
            onRefresh: _refreshNearbyAlerts,
            onToggleLocationSharing: _handleLocationSharingChanged,
            onTriggerSos: _triggerSos,
            onOpenMap: () => setState(() => _currentIndex = 1),
            onOpenProfile: _openProfileScreen,
            onOpenAlert: _openFollowScreen,
            onOpenActiveSos: _openActiveSosScreen,
            onOpenCategorySheet: () =>
                DashboardSheets.showEmergencyCategories(context, _triggerSos),
          ),
          DashboardMapTab(
            mapsLoaderFuture: _mapsLoaderFuture,
            position: _coordinator.currentPosition,
            nearbyAlerts: _nearbyAlerts,
            isLoadingAlerts: _isLoadingAlerts,
            onRefreshAlerts: _refreshNearbyAlerts,
            onShowLegend: () => DashboardSheets.showMapLegend(context),
            onOpenFollow: _openFollowScreen,
            onEnableLocationSharing: () => _handleLocationSharingChanged(true),
          ),
          DashboardAlertsTab(
            nearbyAlerts: _nearbyAlerts,
            isLoadingAlerts: _isLoadingAlerts,
            alertsError: _alertsError,
            onRefresh: _refreshNearbyAlerts,
            onOpenAlert: _openFollowScreen,
          ),
          DashboardCommunityTab(
            nearbyAlerts: _nearbyAlerts,
            onOpenAlert: _openFollowScreen,
            onOpenProfile: _openProfileScreen,
            onOpenMap: () => setState(() => _currentIndex = 1),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _currentIndex,
        onChanged: _handleBottomNavigation,
        onSos: () =>
            DashboardSheets.showEmergencyCategories(context, _triggerSos),
      ),
    );
  }
}
