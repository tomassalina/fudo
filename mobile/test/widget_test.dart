// Basic smoke test: the app boots on the "Inicio" tab (the home screen
// added by `docs/flutter-vs-nextjs-gap-report.md` Tarea 1), with the bottom
// navigation bar visible.
//
// Stale-test correction: `core/router/app_router.dart`'s `ShellRoute`
// gates the ENTIRE shell chrome (all 4 tabs, including `/home`, this
// router's own `initialLocation`) behind `isLoggedInProvider` now, not just
// individual screens — a deliberate, documented decision ("A logged-out
// visitor must see no bottom nav at all — only the login screen", see that
// builder's own doc comment). `isLoggedInProvider` defaults to `false`, so
// a fresh, unauthenticated boot actually lands on `MyPlacesScreen`'s login
// form now, not `HomeScreen` — this test forces the logged-in branch so it
// can still assert what it's actually named for.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:mobile/data/providers.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots on the Inicio tab home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: FudoConsumersApp()),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FudoConsumersApp)),
    );
    container.read(isLoggedInProvider.notifier).logIn();
    // HomeScreen awaits `merchantsProvider` (a `FutureProvider` reading the
    // bundled local fixtures) for the featured grid — pump until it
    // resolves instead of a single `pump()`.
    await tester.pumpAndSettle();

    // Stale-test correction: the nav is icon-only now, ever (product
    // correction — see `shared/widgets/main_shell.dart`'s `_NavItem` doc
    // comment), so there's no "Inicio" text label to find anymore — assert
    // on the tab's icon instead.
    expect(find.byIcon(Symbols.home), findsOneWidget);
    // The bottom nav is a custom floating pill (design-brief §2.10), not a
    // Material BottomNavigationBar — assert on the QR quick-action icon
    // that's part of it instead of the widget type.
    expect(find.byIcon(Symbols.qr_code_scanner), findsOneWidget);
    // Confirms the new HomeScreen actually renders its content (and not
    // just an empty shell) on first launch. Home is hero-only now, no
    // "Bienvenido a Fudo" welcome copy (see `features/home/home_screen.dart`
    // — deliberate product decision, dropped along with the featured-
    // merchants grid) — assert on the AI search hero's real headline
    // instead.
    expect(find.textContaining('Encontrá dónde comer'), findsOneWidget);
  });
}
