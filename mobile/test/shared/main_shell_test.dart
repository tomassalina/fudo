// Widget test for `MainShell` (design brief §2.10 / backlog item 12): the
// floating pill bottom nav with a central QR quick-action.
//
// `LoyaltyQrSheet` (opened by the QR button) reads `currentConsumerProvider`,
// a `FutureProvider`, so every pump here wraps in a `ProviderScope` and
// flushes an extra frame where the sheet is involved — same pattern as
// `test/features/qr_sheet_test.dart`.
//
// Stale-test correction (product decisions applied after this test was
// first written — see `main_shell.dart`'s class doc comment and
// `openspec/changes/fudo-consumers-mvp/learnings.md` Decisión 19): the nav
// is icon-only now, ever — no text label next to the active tab anymore
// (a product correction, "the product owner wants icons only") — and the
// old "Mis Lugares" tab (index 2) is now the always-visible Perfil/Ingresar
// slot: `Symbols.storefront` doesn't render there anymore, replaced by
// `Symbols.person`/`Symbols.login` depending on `isLoggedInProvider`. The
// active-tab color also isn't `AppTheme.accent` text anymore — `_NavItem`
// now paints the active icon white on a gradient pill, muted
// (`AppTheme.textTertiary`) otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/shared/widgets/main_shell.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  required int currentIndex,
  required ValueChanged<int> onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: MainShell(
          currentIndex: currentIndex,
          onTap: onTap,
          child: const Center(child: Text('Contenido')),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping each of the 4 tabs calls onTap with its index', (
    tester,
  ) async {
    final tapped = <int>[];
    await _pumpShell(tester, currentIndex: 0, onTap: tapped.add);

    await tester.tap(find.byIcon(Symbols.home));
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.search));
    await tester.pump();
    // Index 2 is the always-visible Perfil/Ingresar slot — logged out
    // (`isLoggedInProvider`'s default in this test, no override), it shows
    // `Symbols.login`, not the old `Symbols.storefront`.
    await tester.tap(find.byIcon(Symbols.login));
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.card_giftcard));
    await tester.pump();

    expect(tapped, [0, 1, 2, 3]);
  });

  testWidgets(
    'tapping the central QR button opens the LoyaltyQrSheet without '
    'changing tabs',
    (tester) async {
      final tapped = <int>[];
      await _pumpShell(tester, currentIndex: 0, onTap: tapped.add);

      // The QR button is auth-gated (`MainShell._openQrSheet`, mirroring
      // web's `handleOpenQr`): logged in opens `LoyaltyQrSheet`, logged out
      // redirects to `AppRoutes.myPlaces` via `context.go` instead — which
      // needs a real `GoRouter` this test doesn't set up. Force the
      // logged-in branch so this test can assert what it's actually named
      // for (the sheet opening); the logged-out redirect isn't this test's
      // concern.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShell)),
      );
      container.read(isLoggedInProvider.notifier).logIn();
      await tester.pump();

      expect(find.text('Tu código Fudo'), findsNothing);

      await tester.tap(find.byIcon(Symbols.qr_code_scanner));
      // The sheet is scroll-controlled and animates in; the scan-line
      // animation inside it then loops forever, so a couple of bounded
      // `pump()`s are used instead of `pumpAndSettle()`.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tu código Fudo'), findsOneWidget);
      // The QR action is a transversal shortcut, not a tab: it must not
      // report through `onTap`/`currentIndex` at all.
      expect(tapped, isEmpty);
    },
  );

  testWidgets('the active tab renders visually distinct from inactive ones', (
    tester,
  ) async {
    await _pumpShell(tester, currentIndex: 2, onTap: (_) {});

    final homeIcon = tester.widget<Icon>(find.byIcon(Symbols.home));
    final searchIcon = tester.widget<Icon>(find.byIcon(Symbols.search));
    // Index 2 (Perfil/Ingresar) — logged out by default here, so
    // `Symbols.login`, not the old "Mis Lugares" `Symbols.storefront`.
    final placesIcon = tester.widget<Icon>(find.byIcon(Symbols.login));
    final giftIcon = tester.widget<Icon>(find.byIcon(Symbols.card_giftcard));

    // `_NavItem` colors the active icon white on its gradient pill and
    // every inactive icon `AppTheme.textTertiary` — not `AppTheme.accent`
    // text with no pill, which is what this used to check.
    expect(placesIcon.color, Colors.white);
    expect(homeIcon.color, AppTheme.textTertiary);
    expect(searchIcon.color, AppTheme.textTertiary);
    expect(giftIcon.color, AppTheme.textTertiary);

    // Icon-only nav now (product correction — see this file's top comment)
    // — no text label to assert visibility on anymore, active or not.
  });
}
