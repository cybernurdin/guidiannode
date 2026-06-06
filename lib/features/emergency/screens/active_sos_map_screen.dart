import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../services/emergency_coordinator.dart';
import '../services/google_maps_loader.dart';
import '../utils/formatters.dart';
import '../widgets/guardian_map_view.dart';

class ActiveSosMapScreen extends StatefulWidget {
  const ActiveSosMapScreen({super.key});

  @override
  State<ActiveSosMapScreen> createState() => _ActiveSosMapScreenState();
}

class _ActiveSosMapScreenState extends State<ActiveSosMapScreen> {
  final EmergencyCoordinator _coordinator = EmergencyCoordinator.instance;
  late final Future<void> _mapsLoaderFuture;
  bool _isResolving = false;
  DateTime? _resolvedAt;
  EmergencyAlert? _lastResolvedAlert;

  @override
  void initState() {
    super.initState();
    _mapsLoaderFuture = GoogleMapsLoader.ensureLoaded();
    _coordinator.addListener(_handleCoordinatorUpdated);
  }

  @override
  void dispose() {
    _coordinator.removeListener(_handleCoordinatorUpdated);
    super.dispose();
  }

  void _handleCoordinatorUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmResolveAlert() async {
    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("I'm safe now?"),
        content: const Text(
          'Only close the alert when you are safe or the situation has been handled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep live'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("I'm safe"),
          ),
        ],
      ),
    );

    if (shouldResolve != true || !mounted) {
      return;
    }

    final alertBeforeResolve = _coordinator.activeAlert;
    setState(() => _isResolving = true);

    try {
      await _coordinator.resolveActiveSos();

      if (!mounted) {
        return;
      }

      StatusSnackbar.show(
        context,
        message: 'SOS broadcast ended. Your emergency session is closed.',
        tone: StatusTone.success,
      );
      setState(() {
        _isResolving = false;
        _resolvedAt = DateTime.now();
        _lastResolvedAlert = alertBeforeResolve;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isResolving = false);
      StatusSnackbar.show(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        tone: StatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = _coordinator.activeAlert;
    final currentPosition = _coordinator.currentPosition;

    if (_resolvedAt != null) {
      return _ResolvedView(
        resolvedAt: _resolvedAt!,
        alert: _lastResolvedAlert,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    if (alert == null || currentPosition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live SOS')),
        body: const EmptyState(
          title: 'No active SOS session',
          message:
              'GuardianNode has no active SOS on this device yet. Trigger SOS from the dashboard to begin live tracking.',
          icon: Icons.sos_rounded,
        ),
      );
    }

    final marker = Marker(
      markerId: const MarkerId('victim'),
      position: currentPosition.latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    return Scaffold(
      backgroundColor: AppColors.cleanWhite,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const GuardianAppBar(title: 'Alert Sent!'),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: const BoxDecoration(
                color: AppColors.safetyGreen,
                borderRadius: AppRadii.card,
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppColors.cleanWhite,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.safetyGreen,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Alert Sent!',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.cleanWhite,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Help is on the way.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.cleanWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AlertDetailsCard(
              rows: {
                'Type': formatEmergencyType(alert.emergencyType),
                'Location': currentPosition.displayAddress,
                'Time': formatRelativeTime(alert.createdAt),
                'Alert ID': alert.id,
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const InfoBanner(
              title: 'What happens next?',
              message:
                  'Nearby residents have been notified. Keep calm and keep your phone nearby for updates.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 280,
              child: FutureBuilder<void>(
                future: _mapsLoaderFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ErrorState(
                      title: 'Map unavailable',
                      message: snapshot.error.toString(),
                    );
                  }

                  return ClipRRect(
                    borderRadius: AppRadii.card,
                    child: GuardianMapView(
                      markers: {marker},
                      focusPoints: [currentPosition.latLng],
                      initialCenter: currentPosition.latLng,
                      initialZoom: 16,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DangerButton(
              text: "I'm Safe Now",
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isResolving,
              onPressed: _isResolving ? null : _confirmResolveAlert,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlineActionButton(
              text: 'Back to Home',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedView extends StatelessWidget {
  const _ResolvedView({
    required this.resolvedAt,
    required this.alert,
    required this.onClose,
  });

  final DateTime resolvedAt;
  final EmergencyAlert? alert;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cleanWhite,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const GuardianAppBar(title: 'Incident Resolved'),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      color: AppColors.safetyGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.safetyGreen,
                      size: 72,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Incident Resolved',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.safetyGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "We're glad you're safe.\nThank you to the community responders.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AlertDetailsCard(
              title: 'Resolved At',
              rows: {
                'Time': formatRelativeTime(resolvedAt),
                if (alert != null)
                  'Type': formatEmergencyType(alert!.emergencyType),
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const InfoBanner(
              title: "What's next?",
              message:
                  'If you need medical attention, please seek it immediately. You can still review your emergency history later.',
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: 'Close & Stay Safe',
              icon: Icons.check_rounded,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
