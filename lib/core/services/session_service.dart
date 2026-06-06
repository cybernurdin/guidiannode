import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _sessionStorageKey = 'guardian_node_session';

  static Map<String, dynamic>? _session;
  static SharedPreferences? _preferences;

  static Map<String, dynamic>? get session => _session;

  static String? get accessToken => _session?['access_token']?.toString();

  static Map<String, dynamic>? get currentUser {
    final user = _session?['user'];
    return user is Map<String, dynamic> ? user : null;
  }

  static bool get isAuthenticated {
    final token = accessToken;
    final currentSession = _session;
    return token != null &&
        token.isNotEmpty &&
        currentSession != null &&
        !_isSessionExpired(currentSession);
  }

  static Future<void> ensureInitialized() async {
    _preferences ??= await SharedPreferences.getInstance();
    _session = _readStoredSession();

    if (_session != null && _isSessionExpired(_session!)) {
      clearSession();
    }
  }

  static void setSession(Map<String, dynamic> session) {
    _session = Map<String, dynamic>.from(session);
    _persistSession();
  }

  static void updateCurrentUserFields(Map<String, dynamic> fields) {
    final currentSession = _session;
    final currentUser = currentSession?['user'];

    if (currentSession == null || currentUser is! Map<String, dynamic>) {
      return;
    }

    _session = {
      ...currentSession,
      'user': {...currentUser, ...fields},
    };
    _persistSession();
  }

  static void clearSession() {
    _session = null;
    final prefs = _preferences;
    if (prefs != null) {
      unawaited(prefs.remove(_sessionStorageKey));
    }
  }

  static Map<String, dynamic>? _readStoredSession() {
    final rawSession = _preferences?.getString(_sessionStorageKey);
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final decodedSession = jsonDecode(rawSession);
      if (decodedSession is Map<String, dynamic>) {
        return decodedSession;
      }

      if (decodedSession is Map) {
        return Map<String, dynamic>.from(decodedSession);
      }
    } catch (_) {
      clearSession();
    }

    return null;
  }

  static bool _isSessionExpired(Map<String, dynamic> session) {
    final expiresAtValue = session['expires_at']?.toString();
    if (expiresAtValue == null || expiresAtValue.isEmpty) {
      return false;
    }

    final expiresAt = DateTime.tryParse(expiresAtValue);
    if (expiresAt == null) {
      return false;
    }

    return DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  }

  static void _persistSession() {
    final prefs = _preferences;
    final currentSession = _session;
    if (prefs == null || currentSession == null) {
      return;
    }

    unawaited(prefs.setString(_sessionStorageKey, jsonEncode(currentSession)));
  }

  @visibleForTesting
  static void resetForTesting() {
    _session = null;
    _preferences = null;
  }
}
