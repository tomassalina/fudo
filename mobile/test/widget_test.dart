// Basic smoke test: the app boots and lands on the Search tab's home view
// (design-brief §2.1), with the bottom navigation bar visible.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots on the Search tab home view', (
    WidgetTester tester,
  ) async {
    // SearchScreen's home view now reads riverpod providers (e.g.
    // searchHistoryProvider for "continuar búsqueda"), so it needs a
    // ProviderScope — `main()` provides one via runApp, but this test
    // pumps FudoConsumersApp directly and must supply its own.
    await tester.pumpWidget(
      const ProviderScope(child: FudoConsumersApp()),
    );
    // The home view's typewriter placeholder keeps scheduling further
    // frames forever, so `pump` a bounded number of times instead of
    // `pumpAndSettle` (which would time out waiting for animations to stop).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Buscar'), findsWidgets);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    // Confirms the new SearchScreen actually renders its home view (and not
    // just an empty shell) on first launch.
    expect(find.textContaining('Encontrá dónde comer.'), findsOneWidget);
  });
}
