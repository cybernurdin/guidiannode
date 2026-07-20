import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guidiannode/core/theme/theme.dart';
import 'package:guidiannode/features/auth/screens/permissions_education_screen.dart';
import 'package:guidiannode/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GuardianNodeApp boots into splash experience', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const GuardianNodeApp());

    expect(find.text('GuardianNode'), findsOneWidget);
    expect(
      find.text('Help is one tap away.\nStronger together,\nsafer Cameroon.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });

  testWidgets('permissions education screen does not overflow on mobile size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PermissionsEducationScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Permission guide'), findsOneWidget);
    expect(find.text('Enable location now'), findsOneWidget);
  });
}
