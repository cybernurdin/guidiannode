import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../utils/formatters.dart';
import 'guardian_map_view.dart';

enum GuardianUserMapStyle { hybrid3d, normal, terrain, satellite }

GuardianUserMapStyle _mapStyleFromStorage(String value) {
  return GuardianUserMapStyle.values.firstWhere(
    (style) => style.storageValue == value,
    orElse: () => GuardianUserMapStyle.hybrid3d,
  );
}

GuardianUserMapStyle _loadSavedMapStyle() {
  try {
    return _mapStyleFromStorage(AppPreferences.userMapType);
  } on StateError {
    return GuardianUserMapStyle.hybrid3d;
  }
}

extension GuardianUserMapStyleDetails on GuardianUserMapStyle {
  String get storageValue {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return 'hybrid3d';
      case GuardianUserMapStyle.normal:
        return 'normal';
      case GuardianUserMapStyle.terrain:
        return 'terrain';
      case GuardianUserMapStyle.satellite:
        return 'satellite';
    }
  }

  String get label {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return 'Hybrid 3D';
      case GuardianUserMapStyle.normal:
        return 'Normal';
      case GuardianUserMapStyle.terrain:
        return 'Terrain';
      case GuardianUserMapStyle.satellite:
        return 'Satellite';
    }
  }

  IconData get icon {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return Icons.threed_rotation_rounded;
      case GuardianUserMapStyle.normal:
        return Icons.map_rounded;
      case GuardianUserMapStyle.terrain:
        return Icons.terrain_rounded;
      case GuardianUserMapStyle.satellite:
        return Icons.satellite_alt_rounded;
    }
  }

  MapType get mapType {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return MapType.hybrid;
      case GuardianUserMapStyle.normal:
        return MapType.normal;
      case GuardianUserMapStyle.terrain:
        return MapType.terrain;
      case GuardianUserMapStyle.satellite:
        return MapType.satellite;
    }
  }

  double get initialZoom {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return 17.2;
      case GuardianUserMapStyle.normal:
      case GuardianUserMapStyle.terrain:
      case GuardianUserMapStyle.satellite:
        return 15.8;
    }
  }

  double get initialTilt {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return 45;
      case GuardianUserMapStyle.normal:
      case GuardianUserMapStyle.terrain:
      case GuardianUserMapStyle.satellite:
        return 0;
    }
  }

  double get initialBearing {
    switch (this) {
      case GuardianUserMapStyle.hybrid3d:
        return 18;
      case GuardianUserMapStyle.normal:
      case GuardianUserMapStyle.terrain:
      case GuardianUserMapStyle.satellite:
        return 0;
    }
  }
}

class DashboardMapTab extends StatefulWidget {
  const DashboardMapTab({
    super.key,
    required this.mapsLoaderFuture,
    required this.position,
    required this.nearbyAlerts,
    required this.isLoadingAlerts,
    required this.onRefreshAlerts,
    required this.onShowLegend,
    required this.onOpenFollow,
    required this.onEnableLocationSharing,
  });

  final Future<void> mapsLoaderFuture;
  final PositionSnapshot? position;
  final List<EmergencyAlert> nearbyAlerts;
  final bool isLoadingAlerts;
  final Future<void> Function() onRefreshAlerts;
  final VoidCallback onShowLegend;
  final void Function(EmergencyAlert alert) onOpenFollow;
  final VoidCallback onEnableLocationSharing;

  @override
  State<DashboardMapTab> createState() => _DashboardMapTabState();
}

class _DashboardMapTabState extends State<DashboardMapTab> {
  GoogleMapController? _mapController;
  late GuardianUserMapStyle _mapStyle;

  @override
  void initState() {
    super.initState();
    _mapStyle = _loadSavedMapStyle();
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = widget.position;
    if (currentPosition == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: EmptyState(
          title: 'Map unavailable',
          message: 'Turn on location to see nearby alerts.',
          icon: Icons.map_outlined,
          actionLabel: 'Enable location',
          onAction: widget.onEnableLocationSharing,
        ),
      );
    }

    final markers = _buildMarkers(currentPosition);
    final focusPoints = <LatLng>[
      currentPosition.latLng,
      ...widget.nearbyAlerts.map((alert) => alert.latLng),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<void>(
        future: widget.mapsLoaderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              title: 'Map could not load',
              message: snapshot.error.toString(),
              onRetry: widget.onRefreshAlerts,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GuardianMapView(
                  markers: markers,
                  focusPoints: focusPoints,
                  initialCenter: currentPosition.latLng,
                  initialZoom: _mapStyle.initialZoom,
                  initialTilt: _mapStyle.initialTilt,
                  initialBearing: _mapStyle.initialBearing,
                  mapType: _mapStyle.mapType,
                  buildingsEnabled: true,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  trafficEnabled: false,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  fitBoundsOnUpdate: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _animateToUserLocation();
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.overlaySurfaceFor(context),
                                borderRadius: AppRadii.card,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: const GuardianAppBar(
                                title: 'Live Map',
                                showLogo: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _MapStyleMenu(
                            selectedStyle: _mapStyle,
                            onSelected: _setMapStyle,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _MapIconButton(
                            tooltip: 'Legend',
                            icon: Icons.legend_toggle_rounded,
                            onPressed: widget.onShowLegend,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _MapInfoChip(
                              icon: Icons.my_location_rounded,
                              label: 'Current location',
                            ),
                            _MapInfoChip(
                              icon: Icons.warning_amber_rounded,
                              label:
                                  '${widget.nearbyAlerts.length} nearby alert${widget.nearbyAlerts.length == 1 ? '' : 's'}',
                              tone: widget.nearbyAlerts.isEmpty
                                  ? StatusTone.success
                                  : StatusTone.action,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _MapIconButton(
                          tooltip: 'Recenter',
                          icon: Icons.my_location_rounded,
                          onPressed: _animateToUserLocation,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _MapSummaryPanel(
                        position: currentPosition,
                        nearbyAlerts: widget.nearbyAlerts,
                        isLoadingAlerts: widget.isLoadingAlerts,
                        onRefreshAlerts: widget.onRefreshAlerts,
                        onOpenFollow: widget.onOpenFollow,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Set<Marker> _buildMarkers(PositionSnapshot currentPosition) {
    return <Marker>{
      Marker(
        markerId: const MarkerId('current-user'),
        position: currentPosition.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        zIndexInt: 5,
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
      ...widget.nearbyAlerts.map(
        (alert) => Marker(
          markerId: MarkerId('alert-${alert.id}'),
          position: alert.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(_alertHue(alert)),
          zIndexInt: _alertZIndex(alert),
          infoWindow: InfoWindow(
            title: formatEmergencyType(alert.emergencyType),
            snippet: _alertSnippet(alert),
          ),
          onTap: () => _showAlertSheet(alert),
        ),
      ),
    };
  }

  Future<void> _setMapStyle(GuardianUserMapStyle style) async {
    if (_mapStyle == style) {
      return;
    }

    setState(() => _mapStyle = style);

    try {
      await AppPreferences.setUserMapType(style.storageValue);
    } on StateError {
      // Tests can build this widget without the app bootstrap preference setup.
    }

    if (mounted) {
      await _animateToUserLocation();
    }
  }

  Future<void> _animateToUserLocation() async {
    final controller = _mapController;
    final currentPosition = widget.position;

    if (controller == null || currentPosition == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentPosition.latLng,
          zoom: _mapStyle.initialZoom,
          tilt: _mapStyle.initialTilt,
          bearing: _mapStyle.initialBearing,
        ),
      ),
    );
  }

  void _showAlertSheet(EmergencyAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatEmergencyType(alert.emergencyType),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: _formatStatus(alert.status).toUpperCase(),
                    tone: _statusTone(alert),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _AlertDetailRow(
                icon: Icons.place_rounded,
                label: 'Location',
                value: alert.displayAddress,
              ),
              _AlertDetailRow(
                icon: Icons.near_me_rounded,
                label: 'Distance',
                value: formatDistance(alert.distanceMeters),
              ),
              _AlertDetailRow(
                icon: Icons.schedule_rounded,
                label: 'Reported',
                value: formatRelativeTime(alert.createdAt),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                text: 'View Details',
                icon: Icons.open_in_new_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenFollow(alert);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapSummaryPanel extends StatelessWidget {
  const _MapSummaryPanel({
    required this.position,
    required this.nearbyAlerts,
    required this.isLoadingAlerts,
    required this.onRefreshAlerts,
    required this.onOpenFollow,
  });

  final PositionSnapshot position;
  final List<EmergencyAlert> nearbyAlerts;
  final bool isLoadingAlerts;
  final Future<void> Function() onRefreshAlerts;
  final void Function(EmergencyAlert alert) onOpenFollow;

  @override
  Widget build(BuildContext context) {
    final hasAlerts = nearbyAlerts.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.overlaySurfaceFor(context),
        borderRadius: AppRadii.card,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingAlerts) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Text(
                hasAlerts ? 'Nearby alert' : 'Live map ready',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (hasAlerts)
                const StatusBadge(label: 'LIVE', tone: StatusTone.action),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasAlerts
                ? nearbyAlerts.first.displayAddress
                : position.displayAddress,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasAlerts) ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Alerts',
                    value: '${nearbyAlerts.length}',
                    helper: 'Nearby',
                    tone: StatusTone.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Distance',
                    value: formatDistance(nearbyAlerts.first.distanceMeters),
                    helper: 'From you',
                    tone: StatusTone.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: OutlineActionButton(
                  text: 'Refresh',
                  icon: Icons.refresh_rounded,
                  onPressed: isLoadingAlerts ? null : onRefreshAlerts,
                ),
              ),
              if (hasAlerts) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: CommunityActionButton(
                    label: 'View Details',
                    onPressed: () => onOpenFollow(nearbyAlerts.first),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MapStyleMenu extends StatelessWidget {
  const _MapStyleMenu({required this.selectedStyle, required this.onSelected});

  final GuardianUserMapStyle selectedStyle;
  final ValueChanged<GuardianUserMapStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.isDark(context)
        ? Theme.of(context).colorScheme.primary
        : AppColors.trustBlue;

    return Semantics(
      button: true,
      label: 'Map style: ${selectedStyle.label}',
      child: PopupMenuButton<GuardianUserMapStyle>(
        tooltip: 'Map style',
        initialValue: selectedStyle,
        offset: const Offset(0, AppSpacing.xs),
        onSelected: onSelected,
        itemBuilder: (context) {
          return GuardianUserMapStyle.values.map((style) {
            return PopupMenuItem<GuardianUserMapStyle>(
              value: style,
              child: Row(
                children: [
                  Icon(style.icon, color: AppColors.trustBlue),
                  const SizedBox(width: AppSpacing.sm),
                  Text(style.label),
                ],
              ),
            );
          }).toList();
        },
        child: _MapControlSurface(
          icon: selectedStyle.icon,
          foreground: foreground,
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = onPressed == null
        ? AppColors.disabledFor(context)
        : AppColors.isDark(context)
        ? Theme.of(context).colorScheme.primary
        : AppColors.trustBlue;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadii.button,
            child: _MapControlSurface(icon: icon, foreground: foreground),
          ),
        ),
      ),
    );
  }
}

class _MapControlSurface extends StatelessWidget {
  const _MapControlSurface({required this.icon, required this.foreground});

  final IconData icon;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.overlaySurfaceFor(context),
        borderRadius: AppRadii.button,
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: foreground),
    );
  }
}

class _MapInfoChip extends StatelessWidget {
  const _MapInfoChip({
    required this.icon,
    required this.label,
    this.tone = StatusTone.info,
  });

  final IconData icon;
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final color = switch (tone) {
      StatusTone.success =>
        isDark ? const Color(0xFF34D399) : AppColors.safetyGreen,
      StatusTone.warning =>
        isDark ? AppColors.communityYellow : const Color(0xFF8A5A00),
      StatusTone.error => isDark ? AppColors.darkError : AppColors.error,
      StatusTone.info =>
        isDark ? Theme.of(context).colorScheme.primary : AppColors.trustBlue,
      StatusTone.action =>
        isDark ? const Color(0xFFFFB59B) : AppColors.engagementOrange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlaySurfaceFor(context, alpha: 0.94),
        borderRadius: AppRadii.pill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertDetailRow extends StatelessWidget {
  const _AlertDetailRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _alertHue(EmergencyAlert alert) {
  final status = alert.status.toLowerCase();
  final type = alert.emergencyType.toLowerCase();

  if (status.contains('resolved') || status.contains('safe')) {
    return BitmapDescriptor.hueGreen;
  }
  if (status.contains('warning') || status.contains('caution')) {
    return BitmapDescriptor.hueYellow;
  }
  if (type.contains('security') ||
      type.contains('violence') ||
      type.contains('theft')) {
    return BitmapDescriptor.hueAzure;
  }
  return BitmapDescriptor.hueOrange;
}

int _alertZIndex(EmergencyAlert alert) {
  final status = alert.status.toLowerCase();

  if (status.contains('resolved') || status.contains('safe')) {
    return 1;
  }
  if (status.contains('warning') || status.contains('caution')) {
    return 2;
  }
  return 4;
}

String _alertSnippet(EmergencyAlert alert) {
  final distance = formatDistance(alert.distanceMeters);
  final status = _formatStatus(alert.status);

  if (distance == '--') {
    return status;
  }

  return '$status - $distance away';
}

String _formatStatus(String status) {
  return status
      .split(RegExp(r'[_\s-]+'))
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
      )
      .join(' ');
}

StatusTone _statusTone(EmergencyAlert alert) {
  final status = alert.status.toLowerCase();

  if (status.contains('resolved') || status.contains('safe')) {
    return StatusTone.success;
  }
  if (status.contains('warning') || status.contains('caution')) {
    return StatusTone.warning;
  }
  return StatusTone.action;
}
