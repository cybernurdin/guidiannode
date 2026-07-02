import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static SharedPreferences? _instance;

  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const _showCommunityBannersKey = 'show_community_banners';
  static const _showSafetyTipsKey = 'show_safety_tips';
  static const _themeModeKey = 'theme_mode';
  static const _languageKey = 'language';
  static const _textSizeKey = 'text_size';
  static const _userMapTypeKey = 'user_map_type';

  static Future<void> ensureInitialized() async {
    _instance ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _prefs {
    final prefs = _instance;
    if (prefs == null) {
      throw StateError(
        'AppPreferences.ensureInitialized() must be called before use.',
      );
    }
    return prefs;
  }

  static bool get hasSeenOnboarding =>
      _prefs.getBool(_hasSeenOnboardingKey) ?? false;

  static Future<bool> setHasSeenOnboarding(bool value) =>
      _prefs.setBool(_hasSeenOnboardingKey, value);

  static bool get showCommunityBanners =>
      _prefs.getBool(_showCommunityBannersKey) ?? true;

  static Future<bool> setShowCommunityBanners(bool value) =>
      _prefs.setBool(_showCommunityBannersKey, value);

  static bool get showSafetyTips => _prefs.getBool(_showSafetyTipsKey) ?? true;

  static Future<bool> setShowSafetyTips(bool value) =>
      _prefs.setBool(_showSafetyTipsKey, value);

  static String get themeMode => _prefs.getString(_themeModeKey) ?? 'system';

  static Future<bool> setThemeMode(String value) =>
      _prefs.setString(_themeModeKey, value);

  static String get language => _prefs.getString(_languageKey) ?? 'english';

  static Future<bool> setLanguage(String value) =>
      _prefs.setString(_languageKey, value);

  static String get textSize => _prefs.getString(_textSizeKey) ?? 'medium';

  static Future<bool> setTextSize(String value) =>
      _prefs.setString(_textSizeKey, value);

  static String get userMapType =>
      _prefs.getString(_userMapTypeKey) ?? 'hybrid3d';

  static Future<bool> setUserMapType(String value) =>
      _prefs.setString(_userMapTypeKey, value);

  static void resetForTesting() {
    _instance = null;
  }
}
