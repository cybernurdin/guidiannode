import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _productionApiBaseUrl =
      'https://guidiannode-api-production.up.railway.app';
  static const String _androidEmulatorApiBaseUrl = 'http://10.0.2.2:3000';
  static const String _loopbackApiBaseUrl = 'http://127.0.0.1:3000';

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'VITE_API_BASE_URL',
      defaultValue: '',
    ),
  );

  static const String _apiAuthBaseUrlOverride = String.fromEnvironment(
    'API_AUTH_BASE_URL',
    defaultValue: '',
  );

  static const String _googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: String.fromEnvironment(
      'VITE_GOOGLE_MAPS_API_KEY',
      defaultValue: '',
    ),
  );

  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'VITE_SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
  );

  static const String _whatsappTargetNumber = String.fromEnvironment(
    'WHATSAPP_TARGET_NUMBER',
    defaultValue: String.fromEnvironment(
      'VITE_WHATSAPP_TARGET_NUMBER',
      defaultValue: '',
    ),
  );

  static String get apiBaseUrl {
    // Environment configuration must be checked before the release fallback.
    // This allows Vercel Preview and Production deployments to select the
    // correct Railway backend without changing source code.
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_apiBaseUrlOverride);
    }

    if (_apiAuthBaseUrlOverride.isNotEmpty) {
      return _deriveBaseUrlFromAuthUrl(_apiAuthBaseUrlOverride);
    }

    if (kReleaseMode) {
      return _productionApiBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorApiBaseUrl;
    }

    return _loopbackApiBaseUrl;
  }

  static String get apiAuthBaseUrl {
    if (_apiAuthBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_apiAuthBaseUrlOverride);
    }
    return '$apiBaseUrl/api/auth';
  }

  static Uri get dataDeletionUri => Uri.parse('$apiBaseUrl/data-deletion');

  static String get googleMapsApiKey => _googleMapsApiKey;
  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get whatsappTargetNumber => _whatsappTargetNumber;

  static bool get hasSupabaseRealtimeConfig =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  static const bool showDebugOtpHelper = bool.fromEnvironment(
    'SHOW_DEBUG_OTP_HELPER',
    defaultValue: kDebugMode,
  );

  static String _normalizeBaseUrl(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  static String _deriveBaseUrlFromAuthUrl(String value) {
    final normalizedValue = _normalizeBaseUrl(value);
    const authPath = '/api/auth';

    if (normalizedValue.endsWith(authPath)) {
      return normalizedValue.substring(
        0,
        normalizedValue.length - authPath.length,
      );
    }

    return normalizedValue;
  }
}
