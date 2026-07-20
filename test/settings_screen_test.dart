import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/app_preferences.dart';
import 'package:guidiannode/core/services/app_settings.dart';
import 'package:guidiannode/core/services/session_service.dart';
import 'package:guidiannode/core/theme/theme.dart';
import 'package:guidiannode/features/profile/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SessionService.resetForTesting();
    AppPreferences.resetForTesting();
    await AppPreferences.ensureInitialized();
    await SessionService.ensureInitialized();
    await AppSettings.instance.initialize();
  });

  testWidgets('visible settings controls update and open support screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SettingsScreen()),
    );

    await tester.tap(find.text('App Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.themeMode, ThemeMode.dark);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pidgin').last);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, AppLanguage.pidgin);

    await tester.tap(find.text('Writing size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large').last);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.textSize, AppTextSize.large);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.showSafetyTips, isFalse);

    await tester.tap(find.text('Help Center').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Emergency help'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('About GuardianNode').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cameroon emergency alert app'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comot').last);
    await tester.pumpAndSettle();
    expect(find.text('You want comot for GuardianNode?'), findsOneWidget);
  });
}
