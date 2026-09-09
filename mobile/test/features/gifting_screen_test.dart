// Widget tests for the "Regalar" (gift cards) screen.
//
// Covers: all 4 tier cards render, selecting Platinum reveals the custom
// amount field, and the CTA button's label/enabled state react to the
// screen's form state.
//
// `GiftingScreen` used to also carry its own `isLoggedInProvider`-based
// login-required gate (Tarea 4, tested here as its own group) — removed
// once confirmed unreachable now that `core/router/app_router.dart`'s
// `ShellRoute` gates the entire shell before this screen can even build
// while logged out (see that screen's own doc comment). Session-gating
// behavior is exercised at the router level instead — see
// `test/core/router/app_router_session_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/gifting/gifting_screen.dart';

void main() {
  Future<void> pumpGiftingScreen(WidgetTester tester) async {
    // `GiftingScreen` is now a `ConsumerStatefulWidget` (it reads
    // `connectionModeProvider`/`dataSourceProvider` on submit — see
    // `gifting_screen.dart`), so it needs a `ProviderScope` ancestor.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const GiftingScreen()),
      ),
    );
    // `pumpAndSettle()` is intentionally NOT used anywhere in this file:
    // `GiftingScreen` drives its tier cards' and CTA button's idle sheen
    // sweep off a shared `_sheenController` that `repeat()`s for as long as
    // the screen is mounted (`gifting_screen.dart`, matching web's
    // `[animation-duration:3.6s]` `animate-fudo-sheen`), so `pumpAndSettle`
    // — which waits for every animation/microtask to go idle — times out by
    // design. Bounded `pump()`s (300ms, comfortably past this screen's own
    // longest transient animation: the 280ms tier-carousel scroll) are used
    // instead, same pattern already established by
    // `test/features/qr_sheet_test.dart` and `test/shared/main_shell_test.dart`
    // for their own always-looping effects.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('giftCustomAmountField')), findsOneWidget);
    expect(find.text('MONTO PERSONALIZADO'), findsOneWidget);
  });

  testWidgets(
    'CTA button label/enabled state depends only on amount, not phone',
    (tester) async {
      await pumpGiftingScreen(tester);

      // Design brief §2.6: the CTA's 3 states ("Corregí el monto" / "Ingresá
      // un monto" / "Comprar y enviar {monto}") are amount-driven ONLY. The
      // phone is optional — Classic has a valid fixed amount by default, so
      // the button must already be enabled with no phone entered at all.
      Text ctaText() => tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('giftCtaButton')),
          matching: find.byType(Text),
        ),
      );
      // `.first`: `_GiftCtaButton`'s own enabled/disabled `Opacity` is the
      // outermost widget in its subtree (the very first match in traversal
      // order), but when the button is enabled its nested `_SheenSweep`
      // (the idle shimmer, `gifting_screen.dart`) also paints its own
      // `Opacity` for the sweep band's fade in/out — a second, deeper match
      // whenever the shared sheen animation's value puts it mid-fade at the
      // moment this is read. Without `.first` this finder is ambiguous
      // (`Bad state: Too many elements`) any time that inner opacity is
      // also non-zero; `.first` pins it to the button's own opacity, not
      // the sheen's, regardless of the sheen's current animation phase.
      Opacity ctaOpacity() => tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const ValueKey('giftCtaButton')),
              matching: find.byType(Opacity),
            )
            .first,
      );

      expect(ctaText().data, 'Comprar y enviar \$12.000');
      expect(ctaOpacity().opacity, 1);
      expect(find.byKey(const ValueKey('giftPhoneField')), findsOneWidget);

      // Switch to Platinum: the label now depends on the custom amount.
      final platinumCard = find.byKey(const ValueKey('giftTierTap_platinum'));
      await tester.ensureVisible(platinumCard);
      await tester.tap(platinumCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(ctaText().data, 'Ingresá un monto');
      expect(ctaOpacity().opacity, lessThan(1));

      await tester.enterText(
        find.byKey(const ValueKey('giftCustomAmountField')),
        '50',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(ctaText().data, 'Corregí el monto');
      expect(find.text('El mínimo es \$121.000'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('giftCustomAmountField')),
        '150000',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(ctaText().data, 'Comprar y enviar \$150.000');
      expect(ctaOpacity().opacity, 1);
    },
  );

  testWidgets(
    'submitting without a phone shows the WhatsApp-share copy, not "Enviada a"',
    (tester) async {
      await pumpGiftingScreen(tester);

      // Classic is selected by default with a valid fixed amount and no
      // phone entered — per §2.6 this must still be submittable.
      await tester.tap(find.byKey(const ValueKey('giftCtaButton')));
      // Opens `_GiftSuccessOverlay`, whose own entrance animation is a
      // finite 1400ms `AnimationController..forward()` (unlike the parent
      // `GiftingScreen`'s repeating sheen, this one does settle) — but the
      // screen underneath the dialog stays mounted with its sheen still
      // looping, so `pumpAndSettle` still can't be used here either. 1500ms
      // comfortably clears the overlay's own animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

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
    // See the previous test's comment: the success overlay's own entrance
    // animation is finite (1400ms), but the screen underneath keeps its
    // sheen looping, so `pumpAndSettle` still can't be used here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('¡Gift card enviada!'), findsOneWidget);
    expect(find.text('Enviada a +54 9 11 1234 5678'), findsOneWidget);
    expect(find.text('Lista para compartir por WhatsApp'), findsNothing);
  });
}
