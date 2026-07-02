import 'package:flutter/material.dart';

import 'app_preferences.dart';

enum AppLanguage { english, french, pidgin }

enum AppTextSize { small, medium, large }

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.english;
  AppTextSize _textSize = AppTextSize.medium;
  bool _showSafetyTips = true;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  AppTextSize get textSize => _textSize;
  bool get showSafetyTips => _showSafetyTips;

  Locale get locale => switch (_language) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.french => const Locale('fr'),
    AppLanguage.pidgin => const Locale('pcm'),
  };

  double get textScaleFactor => switch (_textSize) {
    AppTextSize.small => 0.9,
    AppTextSize.medium => 1.0,
    AppTextSize.large => 1.15,
  };

  String get themeLabel => switch (_themeMode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System default',
  };

  String get languageLabel => switch (_language) {
    AppLanguage.english => 'English',
    AppLanguage.french => 'French',
    AppLanguage.pidgin => 'Pidgin',
  };

  String get textSizeLabel => switch (_textSize) {
    AppTextSize.small => 'Small',
    AppTextSize.medium => 'Medium',
    AppTextSize.large => 'Large',
  };

  Future<void> initialize() async {
    _themeMode = ThemeMode.values.firstWhere(
      (value) => value.name == AppPreferences.themeMode,
      orElse: () => ThemeMode.system,
    );
    _language = AppLanguage.values.firstWhere(
      (value) => value.name == AppPreferences.language,
      orElse: () => AppLanguage.english,
    );
    _textSize = AppTextSize.values.firstWhere(
      (value) => value.name == AppPreferences.textSize,
      orElse: () => AppTextSize.medium,
    );
    _showSafetyTips = AppPreferences.showSafetyTips;
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await AppPreferences.setThemeMode(value.name);
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    await AppPreferences.setLanguage(value.name);
  }

  Future<void> setTextSize(AppTextSize value) async {
    if (_textSize == value) return;
    _textSize = value;
    notifyListeners();
    await AppPreferences.setTextSize(value.name);
  }

  Future<void> setShowSafetyTips(bool value) async {
    if (_showSafetyTips == value) return;
    _showSafetyTips = value;
    notifyListeners();
    await AppPreferences.setShowSafetyTips(value);
  }
}
