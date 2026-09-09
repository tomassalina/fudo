// `Consumer` is hidden here because it collides with our own domain model
// of the same name (`models/consumer.dart`); this file never needs the
// widget-building `Consumer`.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;

import '../core/analytics/analytics_service.dart';
import '../core/config/dio_client.dart';
import 'auth/auth_repository.dart';
import 'auth/current_consumer_session.dart';
import 'connection_mode.dart';
import 'data_source.dart';
import 'local/local_data_source.dart';
import 'models/business_hour.dart';
import 'models/consumer.dart';
import 'models/consumer_settings.dart';
import 'models/favorite.dart';
import 'models/gift.dart';
import 'models/loyalty_rule.dart';
import 'models/menu_item.dart';
import 'models/merchant.dart';
import 'models/search_history.dart';
import 'models/tag.dart';
import 'models/visit.dart';
import 'models/visit_summary.dart';
import 'remote/remote_data_source.dart';

/// The single source of truth for which [DataSource] implementation the app
/// talks to.
///
/// Picks [LocalDataSource] or [RemoteDataSource] based on [connectionMode]
/// (`data/connection_mode.dart`), which **defaults to `local`** — every
/// screen keeps reading the bundled JSON fixtures unless the app is
/// explicitly built/run with `--dart-define=CONNECTION_MODE=remote`.
///
/// The `remote` branch is real and live-verified: `RemoteDataSource` has been
/// exercised end-to-end against a running backend (login, merchants,
/// favorites, the logged-in consumer — see
/// `test/integration/remote_data_source_live_test.dart` and
/// `test/features/my_places_screen_remote_login_test.dart`), and
/// `features/my_places/my_places_screen.dart` is a real caller of
/// [authRepositoryProvider] when this mode is active. Screens never need to
/// know which branch is active: they only ever depend on the [DataSource]
/// interface via the providers below.
final dataSourceProvider = Provider<DataSource>((ref) {
  return switch (ref.watch(connectionModeProvider)) {
    ConnectionMode.local => LocalDataSource(),
    ConnectionMode.remote => RemoteDataSource(
      ref.watch(dioProvider),
      consumerSession: ref.watch(currentConsumerSessionProvider),
    ),
  };
});

/// Riverpod-visible wrapper around the compile-time [connectionMode] constant
/// (`data/connection_mode.dart`). Screens read/override this provider instead
/// of the raw global so widget tests can force [ConnectionMode.remote] via
/// `ProviderScope(overrides: [connectionModeProvider.overrideWithValue(...)])`
/// without needing a `--dart-define=CONNECTION_MODE=remote` relaunch —
/// `connection_mode.dart` itself stays a plain, dependency-free file.
/// Defaults to the real compile-time [connectionMode] everywhere this isn't
/// overridden.
final connectionModeProvider = Provider<ConnectionMode>((ref) => connectionMode);

/// Shared [Dio] client for [RemoteDataSource] and [AuthRepository], built by
/// `core/config/dio_client.dart`. Only exercised when [connectionMode] is
/// [ConnectionMode.remote] — `features/my_places/my_places_screen.dart` is
/// the real caller of [authRepositoryProvider] in that mode.
///
/// [DioClient.create]'s `onUnauthorized` hook is wired here (not inside
/// `dio_client.dart` itself, which stays Riverpod-free) to react to a real
/// `401` the same way `features/my_places/my_places_screen.dart`'s
/// "Cerrar sesión" button already does: clear the in-memory
/// [currentConsumerSessionProvider] snapshot, then flip [isLoggedInProvider]
/// to `false` so the `ShellRoute`-level auth gate
/// (`core/router/app_router.dart`) reactively redirects to the login screen
/// — no direct navigation call needed here, the router is already watching
/// [isLoggedInProvider]. Clearing the PERSISTED token/consumer snapshot is
/// `dio_client.dart`'s own job on every `401` regardless of caller (see
/// [TokenStorage.clearSession]), not repeated here.
///
/// Deliberately does NOT call `ref.read(authRepositoryProvider).logout()`
/// here even though that would look like the more obvious reuse of the
/// existing "Cerrar sesión" code path: [authRepositoryProvider] itself
/// `ref.watch`es this provider to build its [Dio], and reading it back from
/// inside THIS provider's own `onUnauthorized` closure — invoked later,
/// from inside a request's error interceptor, not during this provider's
/// build — was confirmed live (a throwaway debug run) to throw Riverpod's
/// `CircularDependencyError` at that read, not a build-time analyzer
/// error. Reaching into [currentConsumerSessionProvider] directly instead
/// avoids the cycle entirely, since that provider has no dependency on this
/// one.
final dioProvider = Provider<Dio>((ref) {
  return DioClient.create(
    onUnauthorized: () {
      ref.read(currentConsumerSessionProvider).consumer = null;
      ref.read(isLoggedInProvider.notifier).logOut();
    },
  );
});

/// Single [CurrentConsumerSession] instance shared between
/// [authRepositoryProvider] (which writes to it after a successful login)
/// and [dataSourceProvider]'s [RemoteDataSource] (which reads it back in
/// `getCurrentConsumer()`) — see that class's doc for why this exists at all
/// (there is no "get my own profile" endpoint in the real API).
final currentConsumerSessionProvider = Provider<CurrentConsumerSession>(
  (ref) => CurrentConsumerSession(),
);

/// Login/logout for the demo consumer — see `data/auth/auth_repository.dart`
/// for the confirmed `POST /sessions`/`POST /registrations` contract this
/// makes. Consumed by `features/my_places/my_places_screen.dart` when
/// [connectionMode]/[connectionModeProvider] is [ConnectionMode.remote].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    consumerSession: ref.watch(currentConsumerSessionProvider),
  );
});

/// Wraps PostHog behind business-named tracking methods (see
/// `core/analytics/analytics_service.dart`) so screens depend on
/// [AnalyticsService], not the raw PostHog SDK, and can be read via
/// `ref.read(analyticsServiceProvider)`.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});

/// All merchants available in the app (search results, map pins).
final merchantsProvider = FutureProvider<List<Merchant>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getMerchants();
});

/// A single merchant by id, or `null` if it doesn't exist.
final merchantProvider = FutureProvider.family<Merchant?, int>((
  ref,
  merchantId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getMerchant(merchantId);
});

/// Menu items for a given merchant.
final menuItemsProvider = FutureProvider.family<List<MenuItem>, int>((
  ref,
  merchantId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getMenuItems(merchantId);
});

/// Every menu item across every merchant (the "Buscar" tab's "Platos" result
/// mode — `features/search/widgets/dish_results_list.dart`).
final allMenuItemsProvider = FutureProvider<List<MenuItem>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getAllMenuItems();
});

/// Business hours for a given merchant.
final businessHoursProvider = FutureProvider.family<List<BusinessHour>, int>((
  ref,
  merchantId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getBusinessHours(merchantId);
});

/// Loyalty ladder rules for a given merchant.
final loyaltyRulesProvider = FutureProvider.family<List<LoyaltyRule>, int>((
  ref,
  merchantId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getLoyaltyRules(merchantId);
});

/// All merchants' business hours, grouped by merchant id. Used by the search
/// filters sheet's "Abierto ahora" filter (design brief §2.9) to compute
/// open/closed status for the whole result set without one request per
/// merchant.
final businessHoursByMerchantProvider =
    FutureProvider<Map<int, List<BusinessHour>>>((ref) {
      final dataSource = ref.watch(dataSourceProvider);
      return dataSource.getBusinessHoursByMerchant();
    });

/// All merchants' loyalty ladder rules, grouped by merchant id. Used by the
/// search filters sheet's "Solo con premio de fidelización disponible"
/// filter (design brief §2.9) to compute reward availability for the whole
/// result set without one request per merchant.
final loyaltyRulesByMerchantProvider =
    FutureProvider<Map<int, List<LoyaltyRule>>>((ref) {
      final dataSource = ref.watch(dataSourceProvider);
      return dataSource.getLoyaltyRulesByMerchant();
    });

/// All tags known to the app.
final tagsProvider = FutureProvider<List<Tag>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getTags();
});

/// Tags associated with a merchant.
final tagsForMerchantProvider = FutureProvider.family<List<Tag>, int>((
  ref,
  merchantId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getTagsForMerchant(merchantId);
});

/// All merchant→tag associations, grouped by merchant id. Used by the search
/// filters sheet's "dieta" filter (design brief §2.9) to filter the whole
/// merchant list by tag without one request per merchant.
final merchantTagIdsProvider = FutureProvider<Map<int, Set<int>>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getMerchantTagIdsByMerchant();
});

/// Tags associated with a menu item (detail screen's "Menú" sub-tab, diet
/// tags like vegano/sin TACC on each dish card).
final tagsForMenuItemProvider = FutureProvider.family<List<Tag>, int>((
  ref,
  menuItemId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getTagsForMenuItem(menuItemId);
});

/// The logged-in consumer's own profile.
///
/// This `FutureProvider` computes once and caches. In `ConnectionMode.remote`,
/// the underlying value comes from `CurrentConsumerSession` (a plain mutable
/// field `AuthRepository.login()`/`.logout()` write to directly) — mutating
/// that field does NOT trigger a Riverpod rebuild on its own. Resolved (fase
/// 4, real login wiring): `features/my_places/my_places_screen.dart` is the
/// real caller now, and it calls `ref.invalidate(currentConsumerProvider)`
/// right after a successful login so this re-fetches from the fresh session
/// snapshot instead of showing a stale/`null` consumer. `local` mode is
/// unaffected either way — `LocalDataSource`'s consumer never changes at
/// runtime.
final currentConsumerProvider = FutureProvider<Consumer>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getCurrentConsumer();
});

/// The demo consumer's app settings (theme, notifications).
final consumerSettingsProvider = FutureProvider<ConsumerSettings>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getConsumerSettings();
});

/// The demo consumer's per-merchant visit summaries, optionally scoped to a
/// single merchant. Pass `null` to get all of them.
final visitSummariesProvider = FutureProvider.family<List<VisitSummary>, int?>(
  (ref, merchantId) {
    final dataSource = ref.watch(dataSourceProvider);
    return dataSource.getVisitSummaries(merchantId: merchantId);
  },
);

/// The demo consumer's raw visit history, optionally scoped to a single
/// merchant. Pass `null` to get all of them.
final visitsProvider = FutureProvider.family<List<Visit>, int?>((
  ref,
  merchantId,
) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getVisits(merchantId: merchantId);
});

/// The demo consumer's favorited merchants.
final favoritesProvider = FutureProvider<List<Favorite>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getFavorites();
});

/// Gift cards sent by the demo consumer.
final giftsProvider = FutureProvider<List<Gift>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getGifts();
});

/// The demo consumer's past searches.
final searchHistoryProvider = FutureProvider<List<SearchHistory>>((ref) {
  final dataSource = ref.watch(dataSourceProvider);
  return dataSource.getSearchHistory();
});

/// In-memory set of favorited merchant ids.
///
/// Seeded from [favoritesProvider] the first time it's read, then mutated
/// directly by the UI (e.g. tapping a heart icon on a merchant card) via
/// [toggle] so the tap feels instant. In [ConnectionMode.remote], [toggle]
/// also persists the change against the real backend
/// (`DataSource.addFavorite`/`removeFavorite`) in the background and reverts
/// the optimistic state if that call fails — see [toggle]'s doc. In
/// [ConnectionMode.local], the persistence call is a same-process in-memory
/// mutation on [LocalDataSource] that never throws, so the optimistic update
/// is effectively the only thing that happens.
class FavoriteIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    // Seed synchronously from whatever favoritesProvider currently has, and
    // keep listening so a first successful load populates the initial set.
    ref.listen<AsyncValue<List<Favorite>>>(favoritesProvider, (
      previous,
      next,
    ) {
      final favorites = next.value;
      if (favorites == null) return;
      state = favorites.map((f) => f.merchantId).toSet();
    });

    final favorites = ref.watch(favoritesProvider).value;
    if (favorites == null) return <int>{};
    return favorites.map((f) => f.merchantId).toSet();
  }

  /// Adds or removes [merchantId] from the favorited set, optimistically —
  /// the UI updates immediately, before the network call below resolves —
  /// then fires the matching `DataSource.addFavorite`/`removeFavorite` call
  /// in the background.
  ///
  /// If that call throws a [DioException] (only reachable in
  /// [ConnectionMode.remote] — `LocalDataSource` never throws here), the
  /// optimistic change is reverted back to whatever [merchantId]'s
  /// membership was before this call. There's no toast/snackbar mechanism
  /// established elsewhere in this codebase to surface the failure, so this
  /// deliberately keeps the error handling to "don't leave the UI showing a
  /// favorite that isn't actually persisted" rather than inventing a new
  /// error-notification system for just this one case.
  void toggle(int merchantId) {
    final current = state;
    final wasFavorited = current.contains(merchantId);
    state = wasFavorited
        ? ({...current}..remove(merchantId))
        : {...current, merchantId};

    final dataSource = ref.read(dataSourceProvider);
    final future = wasFavorited
        ? dataSource.removeFavorite(merchantId)
        : dataSource.addFavorite(merchantId);

    future.catchError((Object error) {
      if (error is! DioException) throw error;
      // Revert to the pre-toggle membership — not just "flip back" — in
      // case other toggles landed on [state] while this call was in flight.
      final reverted = {...state};
      if (wasFavorited) {
        reverted.add(merchantId);
      } else {
        reverted.remove(merchantId);
      }
      state = reverted;
    });
  }
}

/// Mutable in-memory favorite merchant ids, seeded from [favoritesProvider].
final favoriteIdsProvider = NotifierProvider<FavoriteIdsNotifier, Set<int>>(
  FavoriteIdsNotifier.new,
);

/// Whether the user is "logged in" — the UI flag the `ShellRoute`-level auth
/// gate (`core/router/app_router.dart`) switches the whole shell on, between
/// the login form ([MyPlacesScreen]'s `_LoggedOutView`) and the real 4-tab
/// nav.
///
/// Extracted from `features/my_places/my_places_screen.dart` (formerly a
/// private `_isLoggedInProvider` local to that screen — see
/// `docs/flutter-vs-nextjs-gap-report.md`, Tarea 4) so any screen can gate
/// itself on session state, not just `MyPlacesScreen`.
///
/// In [ConnectionMode.local] (the default), tapping "Iniciar sesión" flips
/// this to `true` instantly regardless of what (if anything) was typed into
/// the email/password fields — there is no backend to validate against,
/// matching the original prototype's `login()` handler exactly. There is
/// also nothing to restore on a cold start in this mode — see
/// [sessionRestoreProvider].
///
/// In [ConnectionMode.remote], `MyPlacesScreen`'s login form and
/// `features/auth/register_screen.dart` only call [logIn] after
/// `AuthRepository.login()`/`.register()` actually succeed against the real
/// backend. [build] itself always starts `false` on every provider
/// (re)build — [sessionRestoreProvider] is what may flip it to `true` again
/// shortly after, from a durably persisted session, before the gated shell
/// first paints. [logOut] is also called reactively on a real `401` — see
/// [dioProvider]'s doc.
class IsLoggedInNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void logIn() => state = true;

  void logOut() => state = false;
}

/// Shared session flag — see [IsLoggedInNotifier].
final isLoggedInProvider = NotifierProvider<IsLoggedInNotifier, bool>(
  IsLoggedInNotifier.new,
);

/// Restores a durably-persisted session on cold start, so a real login
/// (`AuthRepository.login()`/`.register()`, [ConnectionMode.remote] only)
/// actually survives an app relaunch instead of silently resetting to
/// logged-out every time despite the JWT still being valid in
/// `TokenStorage` — see that class's doc and
/// `data/auth/current_consumer_session.dart`'s doc for the full picture of
/// what was missing before this provider existed.
///
/// Watched exactly once, at the top of the widget tree
/// (`core/router/app_router.dart`'s `ShellRoute` builder, before it reads
/// [isLoggedInProvider] to decide what to show) so the app can render a
/// loading state while this resolves instead of flashing the logged-out
/// login screen and then flipping to logged-in a moment later.
///
/// A no-op in [ConnectionMode.local] — that mode's fake login
/// ([IsLoggedInNotifier.logIn], called directly by
/// `my_places_screen.dart`'s `_onLoginPressed`) never touches
/// [TokenStorage] at all, so there is nothing durable to restore, and this
/// resolves immediately without touching secure storage or the network.
///
/// In [ConnectionMode.remote]:
/// 1. [AuthRepository.restoreSession] loads whatever [TokenStorage] has on
///    disk (token + consumer snapshot) into [currentConsumerSessionProvider]
///    — a purely local operation, see that method's doc.
/// 2. If there was nothing to restore, this is done — [isLoggedInProvider]
///    stays at its default `false`.
/// 3. Otherwise, the loaded token is confirmed against the real backend
///    with one authenticated request
///    (`RemoteDataSource.getConsumerSettings()`, the cheapest existing
///    authenticated call — there is no dedicated token-validation/"who am
///    I" endpoint, see `RemoteDataSource.getCurrentConsumer()`'s doc). A
///    confirmed `401` (the token is genuinely invalid/expired) clears the
///    whole session via [AuthRepository.logout] and leaves
///    [isLoggedInProvider] `false` — the same "fail closed" outcome
///    [dioProvider]'s `onUnauthorized` hook produces for a `401` hit mid
///    -session, deliberately reusing it here via the same
///    `getConsumerSettings()` call going through [dioProvider]'s
///    interceptor rather than duplicating that cleanup.
/// 4. Any OTHER failure (offline, timeout, 5xx, …) does not actually prove
///    the token is invalid — this deliberately does NOT log the user out
///    just because the validation request itself couldn't complete; it
///    trusts the locally cached session instead. The rest of the app
///    already handles a real request failing per-screen once further in
///    (e.g. `my_places_screen.dart`'s `NetworkErrorView` on
///    `currentConsumerProvider`), so a flaky/offline cold start ends up
///    showing the cached profile with per-section error states, not a
///    surprise forced logout.
final sessionRestoreProvider = FutureProvider<void>((ref) async {
  if (ref.watch(connectionModeProvider) != ConnectionMode.remote) return;

  final authRepository = ref.watch(authRepositoryProvider);
  final hasPersistedSession = await authRepository.restoreSession();
  if (!hasPersistedSession) return;

  try {
    await ref.read(dataSourceProvider).getConsumerSettings();
  } on DioException catch (error) {
    if (error.response?.statusCode == 401) {
      await authRepository.logout();
      return;
    }
    // Fall through to logIn() below — see point 4 above.
  } catch (_) {
    // Same reasoning as the non-401 DioException case above.
  }
  ref.read(isLoggedInProvider.notifier).logIn();
});
