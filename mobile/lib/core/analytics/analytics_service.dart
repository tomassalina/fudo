import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Placeholder PostHog Cloud project API key checked into the repo.
///
/// **This is not a real key and must never become one via a hardcoded
/// literal.** The real key belongs in an untracked `mobile/.env` file (copy
/// `mobile/.env.example`, see `ENV_SETUP.md` §4) or a CI secret, passed in at
/// build/run time via `--dart-define=POSTHOG_API_KEY=...` or
/// `--dart-define-from-file=mobile/.env` — never committed to git.
const String posthogApiKeyPlaceholder = 'phc_REPLACE_ME';

/// The PostHog project API key resolved at compile time from
/// `--dart-define`/`--dart-define-from-file` (`POSTHOG_API_KEY`), falling
/// back to [posthogApiKeyPlaceholder] when none was supplied — which is the
/// case for every local `flutter run`/`flutter test` invocation today.
const String posthogApiKey = String.fromEnvironment(
  'POSTHOG_API_KEY',
  defaultValue: posthogApiKeyPlaceholder,
);

/// The PostHog Cloud ingestion host (region-specific, see `ENV_SETUP.md`
/// §4). Resolved the same way as [posthogApiKey]; defaults to the US region.
const String posthogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://us.i.posthog.com',
);

/// Whether a real (non-placeholder) PostHog API key is configured.
///
/// `main.dart` only calls `Posthog().setup(...)` when this is `true`, and
/// [AnalyticsService] checks the same flag before touching the SDK, so both
/// stay in sync without any shared mutable state: as long as the placeholder
/// key is in place (every local dev/test run today), analytics is a
/// guaranteed no-op and never makes a network request.
bool get isPosthogConfigured =>
    posthogApiKey.isNotEmpty && posthogApiKey != posthogApiKeyPlaceholder;

/// Thin wrapper around the PostHog SDK that exposes business-named tracking
/// methods, so screens never call `Posthog()` directly.
///
/// Every method is a safe no-op (optionally logged in debug builds via
/// `debugPrint`) whenever [isPosthogConfigured] is `false` — i.e. whenever
/// PostHog hasn't been set up with a real API key, which today is always,
/// including under `flutter test`. Methods are fire-and-forget on purpose:
/// screens call them synchronously from event handlers (tab taps, search
/// submits, navigation) and must never `await` analytics or have a capture
/// failure surface as a user-facing error.
class AnalyticsService {
  const AnalyticsService();

  /// The user switched to a different bottom-nav tab (`main_shell.dart`).
  void trackTabChanged(String tabName) {
    _capture('tab_changed', {'tab_name': tabName});
  }

  /// The user submitted a search query from the "Buscar" tab
  /// (`search_screen.dart`).
  void trackSearchSubmitted(String query) {
    _capture('search_submitted', {'query': query});
  }

  /// The user opened a restaurant's detail screen
  /// (`restaurant_detail_screen.dart`).
  void trackMerchantOpened(int merchantId) {
    _capture('merchant_opened', {'merchant_id': merchantId});
  }

  /// The user favorited/unfavorited a merchant (`favoriteIdsProvider`).
  void trackFavoriteToggled(int merchantId, bool isFavorite) {
    _capture('favorite_toggled', {
      'merchant_id': merchantId,
      'is_favorite': isFavorite,
    });
  }

  /// The user completed a gift card purchase (`gifting_screen.dart`).
  void trackGiftPurchased(String tierName, double amount) {
    _capture('gift_purchased', {'tier_name': tierName, 'amount': amount});
  }

  void _capture(String eventName, Map<String, Object> properties) {
    if (!isPosthogConfigured) {
      if (kDebugMode) {
        debugPrint('[AnalyticsService] (disabled) $eventName $properties');
      }
      return;
    }
    unawaited(
      Posthog()
          .capture(eventName: eventName, properties: properties)
          .catchError((Object error) {
            if (kDebugMode) {
              debugPrint('[AnalyticsService] capture failed: $error');
            }
          }),
    );
  }
}
