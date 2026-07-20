import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/app_preferences.dart';
import 'package:guidiannode/core/services/app_settings.dart';
import 'package:guidiannode/core/services/session_service.dart';
import 'package:guidiannode/core/theme/colors.dart';
import 'package:guidiannode/core/theme/elevation.dart';
import 'package:guidiannode/core/theme/radii.dart';
import 'package:guidiannode/core/theme/spacing.dart';
import 'package:guidiannode/core/theme/theme.dart';
import 'package:guidiannode/core/widgets/buttons.dart';
import 'package:guidiannode/core/widgets/guardian_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _initPrefs() async {
  SharedPreferences.setMockInitialValues({});
  AppPreferences.resetForTesting();
  SessionService.resetForTesting();
  await AppPreferences.ensureInitialized();
  await SessionService.ensureInitialized();
  await AppSettings.instance.initialize();
}

Widget _material(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: RepaintBoundary(child: child),
    debugShowCheckedModeBanner: false,
  );
}

Future<void> _capture(
  WidgetTester tester,
  Widget widget,
  String filename,
) async {
  await _setPhoneViewport(tester);
  await _initPrefs();
  await tester.pumpWidget(_material(widget));
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile('../screenshots/apk-readiness/$filename'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture fixed opening screen', (tester) async {
    await _capture(tester, const _OpeningPreview(), 'opening_screen.png');
  });

  testWidgets('capture home location ready status', (tester) async {
    await _capture(
      tester,
      const _HomeLocationReadyPreview(),
      'home_location_ready.png',
    );
  });

  testWidgets('capture settings language choices', (tester) async {
    await _capture(
      tester,
      const _SettingsChoicePreview(
        title: 'Language',
        selected: 'English',
        options: ['English', 'French', 'Pidgin'],
      ),
      'settings_language.png',
    );
  });

  testWidgets('capture settings theme choices', (tester) async {
    await _capture(
      tester,
      const _SettingsChoicePreview(
        title: 'App Theme',
        selected: 'System default',
        options: ['Light', 'Dark', 'System default'],
      ),
      'settings_theme.png',
    );
  });
}

class _OpeningPreview extends StatelessWidget {
  const _OpeningPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trustBlue,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                GuardianLogo(
                  size: 120,
                  onDark: true,
                  padding: const EdgeInsets.all(12),
                  borderRadius: 24,
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'GuardianNode',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.cleanWhite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Help is one tap away.\nStronger together,\nsafer Cameroon.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.cleanWhite,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 92,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.cleanWhite,
                    backgroundColor: Color(0x4DFFFFFF),
                  ),
                ),
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _HomeLocationReadyPreview extends StatelessWidget {
  const _HomeLocationReadyPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _HomeHeaderPreview(),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PreviewLocationCard(),
                const SizedBox(height: AppSpacing.lg),
                const _PreviewSafetyTip(),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SosButton(
                    onPressed: () {},
                    isSafeState: false,
                    label: 'SOS',
                    subtitle: 'TAP FOR HELP',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Quick Actions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: const [
                    Expanded(
                      child: _PreviewActionTile(
                        label: 'Call Emergency',
                        color: AppColors.safetyGreen,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _PreviewActionTile(
                        label: 'Report Incident',
                        color: AppColors.communityYellow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeaderPreview extends StatelessWidget {
  const _HomeHeaderPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.trustBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const GuardianLogo(
                    size: 46,
                    onDark: true,
                    padding: EdgeInsets.all(3),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Good morning,\nResident',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: AppColors.cleanWhite,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                    ),
                  ),
                  const _InitialBadge(label: 'R'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.cleanWhite.withValues(alpha: 0.12),
                  borderRadius: AppRadii.card,
                  border: Border.all(
                    color: AppColors.cleanWhite.withValues(alpha: 0.18),
                  ),
                  boxShadow: AppElevation.soft,
                ),
                child: Row(
                  children: [
                    const _SmallMark(color: AppColors.cleanWhite),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "Cameroon, We've Got You.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.cleanWhite,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLocationCard extends StatelessWidget {
  const _PreviewLocationCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.safetyGreenSurface,
              borderRadius: AppRadii.card,
              border: Border.all(
                color: AppColors.safetyGreen.withValues(alpha: 0.2),
              ),
            ),
            child: const Center(
              child: _SmallMark(color: AppColors.safetyGreen),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Location ready',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.safetyGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _PreviewSafetyTip extends StatelessWidget {
  const _PreviewSafetyTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.trustBlueSurface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.trustBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const _SmallMark(color: AppColors.trustBlue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety tip',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.trustBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Keep location enabled and stay where responders can reach you safely.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.trustBlue,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _PreviewActionTile extends StatelessWidget {
  const _PreviewActionTile({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.card,
            ),
            child: Center(child: _SmallMark(color: color)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SettingsChoicePreview extends StatelessWidget {
  const _SettingsChoicePreview({
    required this.title,
    required this.selected,
    required this.options,
  });

  final String title;
  final String selected;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const _SettingsListPreview(),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.cleanWhite,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: AppElevation.soft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...options.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          _ChoiceIndicator(selected: option == selected),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            option,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsListPreview extends StatelessWidget {
  const _SettingsListPreview();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Row(
          children: [
            const GuardianLogo(size: 46, padding: EdgeInsets.all(4)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Preferences',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.md),
        const _SettingsPreviewTile(
          marker: 'A',
          title: 'Language',
          subtitle: 'English',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SettingsPreviewTile(
          marker: 'T',
          title: 'App Theme',
          subtitle: 'System default',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SettingsPreviewTile(
          marker: 'Aa',
          title: 'Text Size',
          subtitle: 'Medium',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SettingsPreviewTile(
          marker: '!',
          title: 'Safety Tips',
          subtitle: 'Visible on dashboard',
          showSwitch: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Support',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.md),
        const _SettingsPreviewTile(
          marker: '?',
          title: 'Help Center',
          subtitle: 'Emergency use and account support.',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SettingsPreviewTile(
          marker: 'i',
          title: 'About GuardianNode',
          subtitle: 'Cameroon emergency alert app.',
        ),
      ],
    );
  }
}

class _SettingsPreviewTile extends StatelessWidget {
  const _SettingsPreviewTile({
    required this.marker,
    required this.title,
    required this.subtitle,
    this.showSwitch = false,
  });

  final String marker;
  final String title;
  final String subtitle;
  final bool showSwitch;

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.trustBlueSurface,
              borderRadius: AppRadii.card,
            ),
            child: Center(
              child: Text(
                marker,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.trustBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          showSwitch
              ? Container(
                  width: 52,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.safetyGreen.withValues(alpha: 0.3),
                    borderRadius: AppRadii.pill,
                  ),
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.safetyGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : const Text(
                  '›',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    height: 1,
                    fontWeight: FontWeight.w300,
                  ),
                ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.soft,
      ),
      child: child,
    );
  }
}

class _ChoiceIndicator extends StatelessWidget {
  const _ChoiceIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.trustBlue, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.trustBlue,
                ),
              ),
            )
          : null,
    );
  }
}

class _SmallMark extends StatelessWidget {
  const _SmallMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.cleanWhite.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cleanWhite.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.cleanWhite,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
