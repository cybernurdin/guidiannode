import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/api_client.dart';
import 'package:guidiannode/core/services/app_preferences.dart';
import 'package:guidiannode/core/services/app_settings.dart';
import 'package:guidiannode/core/theme/theme.dart';
import 'package:guidiannode/features/auth/screens/login_screen.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.ensureInitialized();
    await AppSettings.instance.initialize();
  });

  tearDown(ApiClient.resetClientForTesting);

  testWidgets('login shows friendly network errors without backend URLs', (
    tester,
  ) async {
    ApiClient.setClientForTesting(
      MockClient((_) async => throw const SocketException('offline')),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    );

    await tester.enterText(find.byType(TextFormField), '+237 677 03 47 36');
    await tester.tap(find.text('Continue with WhatsApp'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No internet connection. Please check your network and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('10.0.2.2'), findsNothing);
    expect(find.textContaining('localhost'), findsNothing);
    expect(find.textContaining('https://guidiannode'), findsNothing);
  });
}
