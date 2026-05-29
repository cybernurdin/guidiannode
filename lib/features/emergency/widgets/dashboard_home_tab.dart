import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../services/emergency_coordinator.dart';
import '../utils/formatters.dart';

class DashboardHomeTab extends StatelessWidget {
  const DashboardHomeTab({
    super.key,
    required this.coordinator,
    required this.nearbyAlerts,
    required this.isLoadingAlerts,
    required this.alertsError,
    required this.onRefresh,
    required this.onToggleLocationSharing,
    required this.onTriggerSos,
    required this.onOpenMap,
    required this.onOpenProfile,
    required this.onOpenAlert,
    required this.onOpenActiveSos,
    required this.onOpenCategorySheet,
  });

  final EmergencyCoordinator coordinator;
  final List<EmergencyAlert> nearbyAlerts;
  final bool isLoadingAlerts;
  final String? alertsError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(bool enabled) onToggleLocationSharing;
  final Future<void> Function(String emergencyType, {String? description})
  onTriggerSos;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenProfile;
  final void Function(EmergencyAlert alert) onOpenAlert;
  final VoidCallback onOpenActiveSos;
  final VoidCallback onOpenCategorySheet;

  @override
  Widget build(BuildContext context) {
    final currentUser = SessionService.currentUser;
    final fullName = currentUser?['full_name']?.toString() ?? 'Resident';
    final firstName = fullName.split(' ').first;
    final activeAlert = coordinator.activeAlert;
    final showTips = AppPreferences.showSafetyTips;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Floating curved header card
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: ClipRRect(
              borderRadius: AppRadii.card,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A), // Dark obsidian base
                  borderRadius: AppRadii.card,
                ),
                child: Stack(
                  children: [
                    // Internal mesh gradient blobs
                    Positioned(
                      top: -110,
                      right: -70,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.trustBlue.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -90,
                      left: -50,
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.error.withValues(alpha: 0.16),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Glass border outline
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.card,
                        border: Border.all(
                          color: AppColors.cleanWhite.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Header content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const StatusBadge(
                                label: 'GuardianNode live',
                                tone: StatusTone.info,
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.cleanWhite.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.cleanWhite.withValues(
                                      alpha: 0.16,
                                    ),
                                    width: 1.2,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: onOpenProfile,
                                  icon: const Icon(
                                    Icons.account_circle_outlined,
                                    color: AppColors.cleanWhite,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Stay ready, $firstName',
                            style: GoogleFonts.outfit(
                              color: AppColors.cleanWhite,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            activeAlert == null
                                ? 'Your SOS control is ready. Nearby alerts and safe access points are tracked below.'
                                : 'Your emergency session is active and your live position is still streaming.',
                            style: GoogleFonts.inter(
                              color: AppColors.cleanWhite.withValues(
                                alpha: 0.88,
                              ),
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBanner(),
                const SizedBox(height: AppSpacing.md),

                // Location toggle card styled as premium glassmorphic tile
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.card,
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: SwitchListTile.adaptive(
                    value: coordinator.locationSharingEnabled,
                    onChanged: coordinator.isUpdatingLocationSharing
                        ? null
                        : onToggleLocationSharing,
                    activeThumbColor: AppColors.safetyGreen,
                    activeTrackColor: AppColors.safetyGreen.withValues(
                      alpha: 0.3,
                    ),
                    title: Text(
                      'Keep location ready for emergencies',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      coordinator.currentPosition?.displayAddress ??
                          'Enable location sharing so nearby routing and alert discovery can work well.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs + 2),
                      decoration: BoxDecoration(
                        color: AppColors.trustBlueSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_searching_rounded,
                        color: AppColors.trustBlue,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: SosButton(
                    onPressed: () => onTriggerSos('general_distress'),
                    isBusy: coordinator.isTriggeringSos,
                    isSafeState: activeAlert != null,
                    label: activeAlert != null ? 'Live' : 'SOS',
                    subtitle: activeAlert != null
                        ? 'Open active emergency map'
                        : 'Tap once to send emergency alert',
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                if (activeAlert != null)
                  OutlineActionButton(
                    text: 'Open live SOS map',
                    icon: Icons.my_location_rounded,
                    onPressed: onOpenActiveSos,
                  ),

                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Emergency shortcuts',
                  subtitle:
                      'Choose the closest incident type or open the live map directly.',
                  actionLabel: 'More types',
                  onAction: onOpenCategorySheet,
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.22,
                  children: [
                    ActionTile(
                      title: 'Medical',
                      subtitle: 'Health and injury response',
                      icon: Icons.local_hospital_outlined,
                      accentColor: AppColors.safetyGreen,
                      onTap: () => onTriggerSos('medical'),
                    ),
                    ActionTile(
                      title: 'Fire',
                      subtitle: 'Smoke, flames, evacuation',
                      icon: Icons.local_fire_department_outlined,
                      accentColor: AppColors.engagementOrange,
                      onTap: () => onTriggerSos('fire'),
                    ),
                    ActionTile(
                      title: 'Security',
                      subtitle: 'Threats and unsafe situations',
                      icon: Icons.security_outlined,
                      accentColor: AppColors.trustBlue,
                      onTap: () => onTriggerSos('security'),
                    ),
                    ActionTile(
                      title: 'Open map',
                      subtitle: 'Nearby incidents and route context',
                      icon: Icons.map_outlined,
                      accentColor: AppColors.communityYellow,
                      onTap: onOpenMap,
                    ),
                  ],
                ),

                if (showTips) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const InfoBanner(
                    title: 'Safety tip',
                    message:
                        'If you can move safely, head toward a visible public point while keeping your phone available for live location updates.',
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Recent activity',
                  subtitle:
                      'See the most relevant emergency activity in your current radius.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (isLoadingAlerts)
                  const LoadingCardList(count: 2)
                else if (nearbyAlerts.isEmpty)
                  EmptyState(
                    title: 'No nearby incidents right now',
                    message:
                        alertsError ??
                        'GuardianNode will keep listening for realtime alerts around you.',
                    actionLabel: 'Refresh nearby alerts',
                    onAction: onRefresh,
                  )
                else
                  ...nearbyAlerts
                      .take(2)
                      .map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AlertCard(
                            title: formatEmergencyType(alert.emergencyType),
                            subtitle: alert.displayAddress,
                            distance: formatDistance(alert.distanceMeters),
                            time: formatRelativeTime(
                              alert.updatedAt ?? alert.createdAt,
                            ),
                            onTap: () => onOpenAlert(alert),
                            onAction: () => onOpenAlert(alert),
                          ),
                        ),
                      ),

                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Community support',
                  subtitle:
                      'GuardianNode combines nearby alert context with trusted public support points.',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Nearby alerts',
                        value: '${nearbyAlerts.length}',
                        helper: 'Within 3 km',
                        tone: nearbyAlerts.isEmpty
                            ? StatusTone.info
                            : StatusTone.error,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatTile(
                        label: 'Live status',
                        value: activeAlert == null ? 'Idle' : 'Active',
                        helper: activeAlert == null ? 'Ready' : 'Broadcasting',
                        tone: activeAlert == null
                            ? StatusTone.success
                            : StatusTone.action,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const SafeZoneCard(
                  locationName: 'Mile 4 Police Station',
                  distance: '1.2 km',
                ),
                const SizedBox(height: AppSpacing.sm),
                const SafeZoneCard(
                  locationName: 'Regional Hospital Bamenda',
                  distance: '2.4 km',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final activeAlert = coordinator.activeAlert;

    if (activeAlert != null) {
      return StatusBanner.action(
        title: 'Emergency active',
        message:
            'Your SOS is live and your device location is streaming through the existing GuardianNode tracking flow.',
      );
    }

    if (coordinator.locationSharingEnabled) {
      return StatusBanner.success(
        title: 'Ready for faster routing',
        message:
            'Location sharing is enabled, so nearby alert discovery and live guidance can respond faster.',
      );
    }

    return StatusBanner.warning(
      title: 'Location recommended',
      message:
          'Turn on location sharing to improve routing, nearby alert visibility, and active SOS updates.',
    );
  }
}
