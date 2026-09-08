// Basic smoke test: the app boots and lands on the Search tab with the
// bottom navigation bar visible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots on the Search tab', (WidgetTester tester) async {
    await tester.pumpWidget(const FudoConsumersApp());
    await tester.pumpAndSettle();

    expect(find.text('Buscar'), findsWidgets);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
