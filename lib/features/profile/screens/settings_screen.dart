import 'package:flutter/material.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../auth/screens/legal_document_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../emergency/services/emergency_coordinator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final EmergencyCoordinator _coordinator = EmergencyCoordinator.instance;

  late bool _showCommunityBanners;
  late bool _showSafetyTips;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _showCommunityBanners = AppPreferences.showCommunityBanners;
    _showSafetyTips = AppPreferences.showSafetyTips;
  }

  Future<void> _toggleLocation(bool value) async {
    setState(() => _isUpdatingLocation = true);
    final success = await _coordinator.setLocationSharingEnabled(value);

    if (!mounted) {
      return;
    }

    setState(() => _isUpdatingLocation = false);

    if (!success && value) {
      StatusSnackbar.show(
        context,
        message:
            _coordinator.locationError ??
            'Location permission could not be enabled.',
        tone: StatusTone.error,
      );
    }
  }

  void _signOut() {
    SessionService.clearSession();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _coordinator,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              const SectionHeader(
                title: 'Alerts and permissions',
                subtitle:
                    'Tune how GuardianNode behaves on this device without touching the backend emergency contracts.',
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsTile(
                icon: Icons.location_searching_rounded,
                title: 'Location sharing',
                subtitle: _coordinator.locationSharingEnabled
                    ? 'Ready for routing and live SOS tracking.'
                    : 'Off until you enable it.',
                trailing: Switch.adaptive(
                  value: _coordinator.locationSharingEnabled,
                  onChanged: _isUpdatingLocation ? null : _toggleLocation,
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Community banners',
                subtitle:
                    'Show in-app banners when nearby realtime alerts arrive.',
                trailing: Switch.adaptive(
                  value: _showCommunityBanners,
                  onChanged: (value) async {
                    await AppPreferences.setShowCommunityBanners(value);
                    if (!mounted) {
                      return;
                    }
                    setState(() => _showCommunityBanners = value);
                  },
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsTile(
                icon: Icons.tips_and_updates_outlined,
                title: 'Safety tips on dashboard',
                subtitle: 'Keep short guidance visible in the home experience.',
                trailing: Switch.adaptive(
                  value: _showSafetyTips,
                  onChanged: (value) async {
                    await AppPreferences.setShowSafetyTips(value);
                    if (!mounted) {
                      return;
                    }
                    setState(() => _showSafetyTips = value);
                  },
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                title: 'Privacy and support',
                subtitle:
                    'Read how GuardianNode handles data, location, and appropriate emergency use.',
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy policy',
                subtitle: 'Review how account and location data are handled.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        title: 'Privacy Policy',
                        content:
                            'GuardianNode stores account details, emergency contact information, and emergency-related location updates to support SOS response, OTP verification, and realtime routing.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsTile(
                icon: Icons.gavel_outlined,
                title: 'Terms and conditions',
                subtitle: 'Read platform responsibilities and acceptable use.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        title: 'Terms & Conditions',
                        content:
                            'Use GuardianNode for genuine emergencies. Emergency response timing depends on network, community participation, and backend availability.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              DangerButton(
                text: 'Sign out',
                icon: Icons.logout_rounded,
                onPressed: _signOut,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.trustBlueSurface,
                  borderRadius: AppRadii.card,
                ),
                child: Icon(icon, color: AppColors.trustBlueDark),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
