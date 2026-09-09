// Widget test for `MainShell` (design brief §2.10 / backlog item 12): the
// floating pill bottom nav with a central QR quick-action.
//
// `LoyaltyQrSheet` (opened by the QR button) reads `currentConsumerProvider`,
// a `FutureProvider`, so every pump here wraps in a `ProviderScope` and
// flushes an extra frame where the sheet is involved — same pattern as
// `test/features/qr_sheet_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile/core/theme/app_theme.dart';
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

  testWidgets('tapping each of the 3 tabs calls onTap with its index', (
    tester,
  ) async {
    final tapped = <int>[];
    await _pumpShell(tester, currentIndex: 0, onTap: tapped.add);

    await tester.tap(find.byIcon(Symbols.search));
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.storefront));
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.card_giftcard));
    await tester.pump();

    expect(tapped, [0, 1, 2]);
  });

  testWidgets(
    'tapping the central QR button opens the LoyaltyQrSheet without '
    'changing tabs',
    (tester) async {
      final tapped = <int>[];
      await _pumpShell(tester, currentIndex: 0, onTap: tapped.add);

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
    await _pumpShell(tester, currentIndex: 1, onTap: (_) {});

    final searchIcon = tester.widget<Icon>(find.byIcon(Symbols.search));
    final placesIcon = tester.widget<Icon>(find.byIcon(Symbols.storefront));
    final giftIcon = tester.widget<Icon>(find.byIcon(Symbols.card_giftcard));

    // "Mis Lugares" (index 1) is the active tab here.
    expect(placesIcon.color, AppTheme.accent);
    expect(searchIcon.color, isNot(AppTheme.accent));
    expect(giftIcon.color, isNot(AppTheme.accent));
    expect(searchIcon.color, equals(giftIcon.color));

    // Labels are always mounted (so the width/opacity transition can
    // animate), but only the active tab's label is actually visible.
    AnimatedOpacity labelOpacityFor(String label) => tester.widget(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedOpacity),
      ),
    );

    expect(labelOpacityFor('Mis Lugares').opacity, 1);
    expect(labelOpacityFor('Buscar').opacity, 0);
    expect(labelOpacityFor('Regalar').opacity, 0);
  });
}
