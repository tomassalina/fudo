// `Consumer` is hidden here because it collides with our own domain model
// of the same name (`models/consumer.dart`); this file never needs the
// widget-building `Consumer`.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;

import '../core/analytics/analytics_service.dart';
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

/// The single source of truth for which [DataSource] implementation the app
/// talks to.
///
/// Today it always builds a [LocalDataSource] (reads the bundled JSON
/// fixtures). In Fase 4, when the app switches to the real backend API, this
/// provider's body is the *only* place that needs to change — swap the
/// returned instance for a `RemoteDataSource()` and every screen (which only
/// ever depends on the [DataSource] interface via the providers below)
/// keeps working unmodified.
final dataSourceProvider = Provider<DataSource>((ref) {
  return LocalDataSource();
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

/// The demo-logged-in consumer's own profile.
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
/// directly by the UI (e.g. tapping a heart icon on a merchant card) so the
/// toggle feels instant without re-reading or writing the fixture. This is a
/// demo-only affordance — there's no persistence layer behind it yet.
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

  /// Adds or removes [merchantId] from the favorited set.
  void toggle(int merchantId) {
    final current = state;
    if (current.contains(merchantId)) {
      state = {...current}..remove(merchantId);
    } else {
      state = {...current, merchantId};
    }
  }
}

/// Mutable in-memory favorite merchant ids, seeded from [favoritesProvider].
final favoriteIdsProvider = NotifierProvider<FavoriteIdsNotifier, Set<int>>(
  FavoriteIdsNotifier.new,
);
