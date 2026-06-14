import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/app_preferences.dart';
import 'package:guidiannode/core/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppPreferences.resetForTesting();
    await AppPreferences.ensureInitialized();
    await AppSettings.instance.initialize();
  });

  test('theme, language, text size, and safety tips persist', () async {
    await AppSettings.instance.setThemeMode(ThemeMode.dark);
    await AppSettings.instance.setLanguage(AppLanguage.french);
    await AppSettings.instance.setTextSize(AppTextSize.large);
    await AppSettings.instance.setShowSafetyTips(false);

    expect(AppPreferences.themeMode, 'dark');
    expect(AppPreferences.language, 'french');
    expect(AppPreferences.textSize, 'large');
    expect(AppPreferences.showSafetyTips, isFalse);

    await AppSettings.instance.initialize();
    expect(AppSettings.instance.themeMode, ThemeMode.dark);
    expect(AppSettings.instance.language, AppLanguage.french);
    expect(AppSettings.instance.textSize, AppTextSize.large);
    expect(AppSettings.instance.showSafetyTips, isFalse);
  });
}
