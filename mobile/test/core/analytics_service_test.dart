// Tests for `AnalyticsService` (design brief §5 item 13). No `flutter test`
// run ever supplies `--dart-define=POSTHOG_API_KEY=...`, so
// `posthogApiKey` always resolves to `posthogApiKeyPlaceholder` here —
// `isPosthogConfigured` must be `false` in this environment, and every
// tracking method must be a safe no-op (no crash, no PostHog SDK call,
// no network request) rather than skipped for lack of a test double.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/analytics/analytics_service.dart';

void main() {
  test('the placeholder key is in place under `flutter test`', () {
    // Guards the rest of this file's premise: if this ever fails, it means
    // a real key leaked into source control or the default test runner
    // environment, and the no-op assertions below would no longer be
    // testing what they claim to.
    expect(posthogApiKey, posthogApiKeyPlaceholder);
    expect(isPosthogConfigured, isFalse);
  });

  group('AnalyticsService with the placeholder key', () {
    const analytics = AnalyticsService();

    test('trackTabChanged does not throw', () {
      expect(() => analytics.trackTabChanged('Buscar'), returnsNormally);
    });

    test('trackSearchSubmitted does not throw', () {
      expect(() => analytics.trackSearchSubmitted('pizza'), returnsNormally);
    });

    test('trackMerchantOpened does not throw', () {
      expect(() => analytics.trackMerchantOpened(1), returnsNormally);
    });

    test('trackFavoriteToggled does not throw', () {
      expect(() => analytics.trackFavoriteToggled(1, true), returnsNormally);
    });

    test('trackGiftPurchased does not throw', () {
      expect(() => analytics.trackGiftPurchased('gold', 5000), returnsNormally);
    });
  });
}
