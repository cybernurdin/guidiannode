import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
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
        title: const Text('End SOS broadcast?'),
        content: const Text(
          'Only end the SOS when you are safe or the situation has been handled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep live'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End SOS'),
          ),
        ],
      ),
    );

    if (shouldResolve != true || !mounted) {
      return;
    }

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
      Navigator.of(context).pop();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Live SOS')),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner.action(
                title: 'Emergency broadcast active',
                message:
                    'GuardianNode is continuously streaming your location through the existing live SOS flow.',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Status',
                      value: 'Live',
                      helper: formatEmergencyType(alert.emergencyType),
                      tone: StatusTone.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(
                      label: 'Updated',
                      value: formatRelativeTime(
                        alert.updatedAt ?? alert.createdAt,
                      ),
                      helper: 'Tracking',
                      tone: StatusTone.action,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LocationCard(
                title: currentPosition.displayAddress,
                subtitle:
                    'Keep your phone available so responders and nearby residents can follow the latest position.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
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

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GuardianMapView(
                            markers: {marker},
                            focusPoints: [currentPosition.latLng],
                            initialCenter: currentPosition.latLng,
                            initialZoom: 16,
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
                              'Alert type: ${formatEmergencyType(alert.emergencyType)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DangerButton(
                text: 'End SOS broadcast',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isResolving,
                onPressed: _isResolving ? null : _confirmResolveAlert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
