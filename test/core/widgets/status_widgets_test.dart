import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guidiannode/core/theme/theme.dart';
import 'package:guidiannode/core/widgets/status_widgets.dart';

void main() {
  testWidgets('StatusBanner renders title and message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatusBanner.warning(
            title: 'Attention',
            message: 'Location sharing is currently disabled.',
          ),
        ),
      ),
    );

    expect(find.text('Attention'), findsOneWidget);
    expect(
      find.text('Location sharing is currently disabled.'),
      findsOneWidget,
    );
  });

  testWidgets('StatusBadge renders semantic label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: StatusBadge(label: 'Live', tone: StatusTone.action),
        ),
      ),
    );

    expect(find.text('Live'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
  });
}
