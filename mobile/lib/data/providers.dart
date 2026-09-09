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
final dioProvider = Provider<Dio>((ref) => DioClient.create());

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
