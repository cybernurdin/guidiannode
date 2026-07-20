import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_settings.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
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
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _showCommunityBanners = AppPreferences.showCommunityBanners;
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('sign_out_title')),
        content: Text(context.tr('sign_out_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await SessionService.clearSessionAsync();
    await _coordinator.resetForSignOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<T?> _showChoiceDialog<T>({
    required String title,
    required T current,
    required Map<T, String> choices,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: choices.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(entry.key),
                child: Row(
                  children: [
                    Icon(
                      entry.key == current
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _selectTheme() async {
    final settings = AppSettings.instance;
    final selected = await _showChoiceDialog<ThemeMode>(
      title: context.tr('app_theme'),
      current: settings.themeMode,
      choices: const {
        ThemeMode.light: 'Light',
        ThemeMode.dark: 'Dark',
        ThemeMode.system: 'System default',
      },
    );
    if (selected != null) {
      await settings.setThemeMode(selected);
    }
  }

  Future<void> _selectLanguage() async {
    final settings = AppSettings.instance;
    final selected = await _showChoiceDialog<AppLanguage>(
      title: context.tr('language'),
      current: settings.language,
      choices: const {
        AppLanguage.english: 'English',
        AppLanguage.french: 'French',
        AppLanguage.pidgin: 'Pidgin',
      },
    );
    if (selected != null) {
      await settings.setLanguage(selected);
    }
  }

  Future<void> _selectTextSize() async {
    final settings = AppSettings.instance;
    final selected = await _showChoiceDialog<AppTextSize>(
      title: context.tr('text_size'),
      current: settings.textSize,
      choices: const {
        AppTextSize.small: 'Small',
        AppTextSize.medium: 'Medium',
        AppTextSize.large: 'Large',
      },
    );
    if (selected != null) {
      await settings.setTextSize(selected);
    }
  }

  Future<void> _openDataDeletion() async {
    final opened = await launchUrl(
      AppConfig.dataDeletionUri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted || opened) {
      return;
    }

    StatusSnackbar.show(
      context,
      message: 'The account deletion page could not be opened.',
      tone: StatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_coordinator, AppSettings.instance]),
      builder: (context, _) {
        final settings = AppSettings.instance;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                const GuardianLogo(size: 38, padding: EdgeInsets.all(3)),
                const SizedBox(width: AppSpacing.sm),
                Text(context.tr('settings')),
              ],
            ),
          ),
          body: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              SectionHeader(title: context.tr('general')),
              const SizedBox(height: AppSpacing.md),
              SettingsTile(
                icon: Icons.location_searching_rounded,
                title: context.tr('location_permissions'),
                subtitle: _coordinator.locationSharingEnabled
                    ? context.tr('location_always')
                    : context.tr('location_off_until_enabled'),
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
              SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: context.tr('notifications'),
                subtitle: _showCommunityBanners ? 'On' : 'Off',
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
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: context.tr('privacy_data'),
                subtitle: context.tr('privacy_subtitle'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LegalDocumentScreen(
                        title: 'Privacy Policy',
                        content:
                            'GuardianNode stores account details, emergency contact information, and emergency-related location updates to support SOS response, WhatsApp verification, and realtime routing.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: context.tr('delete_account'),
                subtitle: context.tr('delete_subtitle'),
                onTap: _openDataDeletion,
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: context.tr('preferences')),
              const SizedBox(height: AppSpacing.md),
              SettingsTile(
                icon: Icons.language_rounded,
                title: context.tr('language'),
                subtitle: settings.languageLabel,
                onTap: _selectLanguage,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.light_mode_outlined,
                title: context.tr('app_theme'),
                subtitle: settings.themeLabel,
                onTap: _selectTheme,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.text_fields_rounded,
                title: context.tr('text_size'),
                subtitle: settings.textSizeLabel,
                onTap: _selectTextSize,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.tips_and_updates_outlined,
                title: context.tr('safety_tips'),
                subtitle: settings.showSafetyTips
                    ? context.tr('tips_visible')
                    : context.tr('tips_hidden'),
                trailing: Switch.adaptive(
                  value: settings.showSafetyTips,
                  onChanged: settings.setShowSafetyTips,
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: context.tr('support')),
              const SizedBox(height: AppSpacing.md),
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: context.tr('help_center'),
                subtitle: context.tr('help_subtitle'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HelpCenterScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: context.tr('about'),
                subtitle: context.tr('about_subtitle'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              DangerButton(
                text: context.tr('sign_out'),
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

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final whatsapp = AppConfig.whatsappTargetNumber.trim();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const GuardianLogo(size: 38, padding: EdgeInsets.all(3)),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Help Center')),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SectionHeader(title: 'Emergency help'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'To raise an alert, tap the large red SOS button on the home dashboard. '
              'Select the appropriate category (general distress, medical, fire, or security). '
              'Responders and nearby trusted contacts will be notified with your live location. '
              'Keep location services enabled so responders can route to you.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Account support'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sign-in is permitted only for verified phone numbers registered in the system. '
              'If your session expires or you change devices, you can verify your number using WhatsApp. '
              'If you experience registration issues, verify that your phone is normalized correctly (e.g. +237 for Cameroon numbers).',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            if (whatsapp.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Contact Info'),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.chat_rounded,
                  color: AppColors.safetyGreen,
                ),
                title: const Text('WhatsApp Support'),
                subtitle: Text('+$whatsapp'),
                onTap: () async {
                  final uri = Uri.parse('https://wa.me/$whatsapp');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Basic FAQ'),
            const SizedBox(height: AppSpacing.sm),
            const _FaqTile(
              question: 'Why is my location state "using last known"?',
              answer:
                  'GuardianNode displays this when the device is unable to fetch a fresh GPS snapshot, using your last synchronized profile location as backup. Tap the refresh button to force update.',
            ),
            const _FaqTile(
              question:
                  'Does GuardianNode track my location in the background?',
              answer:
                  'Location updates are only actively streamed during active SOS sessions. Passive checks are periodic and privacy-respecting.',
            ),
            const _FaqTile(
              question: 'How do I change my emergency contact?',
              answer:
                  'Go to your Profile tab (last icon in bottom navigation) to edit your emergency contact details, relationship, and neighborhood settings.',
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        trailing: Icon(
          _expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
        ),
        onExpansionChanged: (val) => setState(() => _expanded = val),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(
              widget.answer,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const GuardianLogo(size: 38, padding: EdgeInsets.all(3)),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('About GuardianNode')),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const GuardianLogo(size: 100),
              const SizedBox(height: AppSpacing.md),
              Text(
                'GuardianNode',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cameroon emergency alert app',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: AppSpacing.md),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Version'),
                trailing: Text(
                  '1.0.0 (build 1)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        title: 'Privacy Policy',
                        content:
                            'GuardianNode stores account details, emergency contact information, and emergency-related location updates to support SOS response, WhatsApp verification, and realtime routing.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data Deletion Request'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () async {
                  await launchUrl(
                    AppConfig.dataDeletionUri,
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
