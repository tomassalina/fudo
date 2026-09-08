// Widget test for `LoyaltyQrSheet` (design brief §2.8).
//
// Only the "Mi QR" tab is exercised here: it's opened via `initialTab:
// LoyaltyQrTab.miQr` so the test never needs a real camera. The "Escanear"
// tab is only checked for the tab switch itself (title/labels render) —
// `mobile_scanner`'s `MobileScannerController` talks to platform channels
// for the actual camera preview, which isn't available in the widget test
// environment, so asserting on the live camera feed itself is out of scope
// here (per task spec).
//
// `tester.pumpAndSettle()` is intentionally NOT used anywhere in this file:
// the sheet's scan-line `AnimationController` runs `repeat(reverse: true)`
// (the `fudoScan` sweep, 2.4s loop) for as long as the widget is mounted, so
// `pumpAndSettle` — which waits for all animations/microtasks to go idle —
// would time out by design. A few explicit `pump()`s are enough to flush the
// initial frame and the tab-switch transition.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/loyalty/qr_sheet.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  LoyaltyQrTab initialTab = LoyaltyQrTab.miQr,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: LoyaltyQrSheet(initialTab: initialTab),
        ),
      ),
    ),
  );
  // First pump renders the loading state of `currentConsumerProvider`; the
  // second flushes the `FutureProvider`'s microtask so "Mi QR" has data.
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the title and the "Mi QR" tab with the ID badge', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('Tu código Fudo'), findsOneWidget);
    expect(find.text('Mi QR'), findsOneWidget);
    expect(find.text('Escanear'), findsOneWidget);

    // Demo consumer id is `00000000-0000-0000-0000-000000000001`
    // (assets/fixtures/consumers.json) → badge is its first 8 hex chars.
    expect(find.text('ID 00000000'), findsOneWidget);
    expect(
      find.text('Mostrale este código al mesero para validar tu visita.'),
      findsOneWidget,
    );
  });

  testWidgets('switching to "Escanear" shows the scan copy', (tester) async {
    await _pumpSheet(tester);

    await tester.tap(find.text('Escanear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Escaneá el QR del local'), findsOneWidget);
    expect(
      find.text('Se suma la visita y aplicamos tu descuento al instante.'),
      findsOneWidget,
    );
  });
}
