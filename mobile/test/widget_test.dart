// Basic smoke test: the app boots on the "Inicio" tab (the home screen
// added by `docs/flutter-vs-nextjs-gap-report.md` Tarea 1), with the bottom
// navigation bar visible.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots on the Inicio tab home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: FudoConsumersApp()),
    );
    // HomeScreen awaits `merchantsProvider` (a `FutureProvider` reading the
    // bundled local fixtures) for the featured grid — pump until it
    // resolves instead of a single `pump()`.
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsWidgets);
    // The bottom nav is a custom floating pill (design-brief §2.10), not a
    // Material BottomNavigationBar — assert on the QR quick-action icon
    // that's part of it instead of the widget type.
    expect(find.byIcon(Symbols.qr_code_scanner), findsOneWidget);
    // Confirms the new HomeScreen actually renders its content (and not
    // just an empty shell) on first launch.
    expect(find.text('Bienvenido a Fudo'), findsOneWidget);
  });
}
