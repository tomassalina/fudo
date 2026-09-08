// Tests for `NetworkErrorView` (shared/widgets/network_error_view.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/shared/widgets/network_error_view.dart';

Future<void> _pumpNetworkErrorView(
  WidgetTester tester, {
  required VoidCallback onRetry,
  String? message,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: NetworkErrorView(
          onRetry: onRetry,
          message: message ?? 'No pudimos conectarnos. Revisá tu conexión.',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the default message and a "Reintentar" button', (
    tester,
  ) async {
    await _pumpNetworkErrorView(tester, onRetry: () {});

    expect(
      find.text('No pudimos conectarnos. Revisá tu conexión.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('renders a custom message when one is provided', (
    tester,
  ) async {
    await _pumpNetworkErrorView(
      tester,
      onRetry: () {},
      message: 'No pudimos cargar los lugares.',
    );

    expect(find.text('No pudimos cargar los lugares.'), findsOneWidget);
    expect(
      find.text('No pudimos conectarnos. Revisá tu conexión.'),
      findsNothing,
    );
  });

  testWidgets('tapping "Reintentar" calls onRetry exactly once', (
    tester,
  ) async {
    var retryCount = 0;
    await _pumpNetworkErrorView(
      tester,
      onRetry: () => retryCount++,
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(retryCount, 1);
  });
}
