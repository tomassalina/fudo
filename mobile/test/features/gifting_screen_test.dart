// Widget tests for the "Regalar" (gift cards) screen.
//
// Covers: all 4 tier cards render, selecting Platinum reveals the custom
// amount field, and the CTA button's label/enabled state react to the
// screen's form state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/gifting/gifting_screen.dart';

void main() {
  Future<void> pumpGiftingScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const GiftingScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the 4 gift tier cards', (tester) async {
    await pumpGiftingScreen(tester);

    expect(find.text('CLASSIC'), findsOneWidget);
    expect(find.text('GOLD'), findsOneWidget);
    expect(find.text('BLACK'), findsOneWidget);
    expect(find.text('PLATINUM'), findsOneWidget);
  });

  testWidgets('selecting Platinum shows the custom amount field', (
    tester,
  ) async {
    await pumpGiftingScreen(tester);

    // Classic (fixed amount) is selected by default — no custom field yet.
    expect(find.byKey(const ValueKey('giftCustomAmountField')), findsNothing);

    final platinumCard = find.byKey(const ValueKey('giftTierTap_platinum'));
    await tester.ensureVisible(platinumCard);
    await tester.tap(platinumCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('giftCustomAmountField')), findsOneWidget);
    expect(find.text('MONTO PERSONALIZADO'), findsOneWidget);
  });

  testWidgets('CTA button label/enabled state depends only on amount, not phone', (
    tester,
  ) async {
    await pumpGiftingScreen(tester);

    // Design brief §2.6: the CTA's 3 states ("Corregí el monto" / "Ingresá
    // un monto" / "Comprar y enviar {monto}") are amount-driven ONLY. The
    // phone is optional — Classic has a valid fixed amount by default, so
    // the button must already be enabled with no phone entered at all.
    Text ctaText() =>
        tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('giftCtaButton')),
          matching: find.byType(Text),
        ));
    Opacity ctaOpacity() => tester.widget<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('giftCtaButton')),
            matching: find.byType(Opacity),
          ),
        );

    expect(ctaText().data, 'Comprar y enviar \$12.000');
    expect(ctaOpacity().opacity, 1);
    expect(find.byKey(const ValueKey('giftPhoneField')), findsOneWidget);

    // Switch to Platinum: the label now depends on the custom amount.
    final platinumCard = find.byKey(const ValueKey('giftTierTap_platinum'));
    await tester.ensureVisible(platinumCard);
    await tester.tap(platinumCard);
    await tester.pumpAndSettle();

    expect(ctaText().data, 'Ingresá un monto');
    expect(ctaOpacity().opacity, lessThan(1));

    await tester.enterText(
      find.byKey(const ValueKey('giftCustomAmountField')),
      '50',
    );
    await tester.pumpAndSettle();

    expect(ctaText().data, 'Corregí el monto');
    expect(find.text('El mínimo es \$121.000'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('giftCustomAmountField')),
      '150000',
    );
    await tester.pumpAndSettle();

    expect(ctaText().data, 'Comprar y enviar \$150.000');
    expect(ctaOpacity().opacity, 1);
  });

  testWidgets(
    'submitting without a phone shows the WhatsApp-share copy, not "Enviada a"',
    (tester) async {
      await pumpGiftingScreen(tester);

      // Classic is selected by default with a valid fixed amount and no
      // phone entered — per §2.6 this must still be submittable.
      await tester.tap(find.byKey(const ValueKey('giftCtaButton')));
      await tester.pumpAndSettle();

      expect(find.text('¡Gift card enviada!'), findsOneWidget);
      expect(find.text('Lista para compartir por WhatsApp'), findsOneWidget);
      expect(find.textContaining('Enviada a'), findsNothing);
    },
  );

  testWidgets('submitting with a phone shows "Enviada a {phone}"', (
    tester,
  ) async {
    await pumpGiftingScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('giftPhoneField')),
      '+54 9 11 1234 5678',
    );
    await tester.tap(find.byKey(const ValueKey('giftCtaButton')));
    await tester.pumpAndSettle();

    expect(find.text('¡Gift card enviada!'), findsOneWidget);
    expect(find.text('Enviada a +54 9 11 1234 5678'), findsOneWidget);
    expect(find.text('Lista para compartir por WhatsApp'), findsNothing);
  });
}
