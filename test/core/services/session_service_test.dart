import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guidiannode/core/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists and restores a valid authenticated session', () async {
    SessionService.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SessionService.ensureInitialized();

    final expiresAt = DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String();

    SessionService.setSession({
      'access_token': 'test-token',
      'expires_at': expiresAt,
      'user': {'id': 'user-1', 'full_name': 'Test User'},
    });

    expect(SessionService.isAuthenticated, isTrue);

    await Future<void>.delayed(Duration.zero);
    SessionService.resetForTesting();
    await SessionService.ensureInitialized();

    expect(SessionService.accessToken, 'test-token');
    expect(SessionService.currentUser?['id'], 'user-1');
  });

  test('clears expired stored sessions', () async {
    SessionService.resetForTesting();
    final expiredAt = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 1))
        .toIso8601String();

    SharedPreferences.setMockInitialValues(<String, Object>{
      'guardian_node_session':
          '{"access_token":"expired-token","expires_at":"$expiredAt","user":{"id":"user-1"}}',
    });

    await SessionService.ensureInitialized();

    expect(SessionService.isAuthenticated, isFalse);
    expect(SessionService.accessToken, isNull);
  });
}
