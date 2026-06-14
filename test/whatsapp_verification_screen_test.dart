import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/session_service.dart';
import 'package:guidiannode/features/auth/screens/whatsapp_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'keeps polling after WhatsApp verification until auth session is ready',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      SessionService.resetForTesting();
      await SessionService.ensureInitialized();

      var statusChecks = 0;
      final navigatorKey = GlobalKey<NavigatorState>();
      final session = {
        'access_token': 'test-access-token',
        'token_type': 'Bearer',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'user': {
          'id': 'test-user-id',
          'full_name': 'Test User',
          'phone_number': '237600000000',
          'quarter': 'Test Quarter',
          'location_permission': false,
          'emergency_contact': {
            'contact_name': 'Test Contact',
            'phone_number': '237600000001',
            'relationship': 'Friend',
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: WhatsappVerificationScreen(
            verificationId: 'verification-id',
            token: 'CM-ABCDE',
            whatsappUrl: 'https://example.com',
            phoneNumber: '237600000000',
            purpose: 'login',
            expiresAt: DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            statusLoader: (_) async {
              statusChecks += 1;

              if (statusChecks == 1) {
                return {
                  'success': true,
                  'status': 'verified',
                  'verified': true,
                  'authReady': false,
                  'nextStep': 'completing_auth',
                };
              }

              return {
                'success': true,
                'status': 'verified',
                'verified': true,
                'authReady': true,
                'nextStep': 'dashboard',
                'session': session,
              };
            },
            onRequestNew: () async => const {'success': false},
            onVerified: (verifiedSession) async {
              await SessionService.setSession(verifiedSession);
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Dashboard reached')),
                ),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('WhatsApp verified. Finishing secure sign-in...'),
        findsOneWidget,
      );
      expect(SessionService.isAuthenticated, isFalse);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(statusChecks, greaterThanOrEqualTo(2));
      expect(SessionService.isAuthenticated, isTrue);
      expect(find.text('Dashboard reached'), findsOneWidget);
    },
  );

  testWidgets(
    'shows create account action when login confirmation phone is unregistered',
    (tester) async {
      var policyCode = '';

      await tester.pumpWidget(
        MaterialApp(
          home: WhatsappVerificationScreen(
            verificationId: 'verification-id',
            token: 'CM-ABCDE',
            whatsappUrl: 'https://wa.me/237657262038?text=CM-ABCDE',
            phoneNumber: '237600000000',
            purpose: 'login',
            expiresAt: DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            statusLoader: (_) async => {
              'success': true,
              'status': 'pending',
              'verified': false,
            },
            whatsappLauncher: (_) async => true,
            confirmClickLoader:
                ({required verificationId, required phoneNumber}) async => {
                  'success': false,
                  'status': 'failed',
                  'code': 'PHONE_NOT_REGISTERED',
                  'message':
                      'This phone number is not registered. Please create an account first.',
                },
            onRequestNew: () async => const {'success': false},
            onAuthRuleFailure: (code) => policyCode = code,
            onVerified: (_) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      final openWhatsappButton = find.text('Open WhatsApp');
      await tester.ensureVisible(openWhatsappButton);
      await tester.tap(openWhatsappButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Account Not Found'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);

      await tester.tap(find.text('Create account'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(policyCode, 'PHONE_NOT_REGISTERED');
      expect(find.text('Account Not Found'), findsNothing);
    },
  );
}
