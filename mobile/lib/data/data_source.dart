import 'models/business_hour.dart';
import 'models/consumer.dart';
import 'models/consumer_settings.dart';
import 'models/favorite.dart';
import 'models/gift.dart';
import 'models/loyalty_rule.dart';
import 'models/menu_item.dart';
import 'models/merchant.dart';
import 'models/search_history.dart';
import 'models/search_query_filters.dart';
import 'models/tag.dart';
import 'models/visit.dart';
import 'models/visit_summary.dart';

/// Abstract data access boundary for the app.
///
/// [DataSource] is implemented today by `local/local_data_source.dart`
/// (reads `mobile/assets/fixtures/*.json`) and, in a future phase, will also
/// be implemented by a `remote/remote_data_source.dart` that talks to the
/// real backend API. Screens and providers depend on this interface only,
/// so swapping the implementation (e.g. in a Riverpod provider override) is
/// a one-line change — no screen code should ever import a concrete
/// implementation directly.
///
/// Method shapes follow the screens described in `docs/design-brief.md` §5:
/// search results/detail need merchants scoped by id, business hours and
/// loyalty rules scoped by merchant, and "Mis Lugares"/"Regalar" need the
/// demo consumer's own visits, favorites, gifts and search history.
abstract class DataSource {
  /// All merchants available in the app (search results, map pins).
  Future<List<Merchant>> getMerchants();

  /// A single merchant by id, or `null` if it doesn't exist. Used by the
  /// restaurant detail screen, which navigates by merchant id.
  Future<Merchant?> getMerchant(int merchantId);

  /// Menu items for a given merchant (detail screen's "Menú" sub-tab).
  Future<List<MenuItem>> getMenuItems(int merchantId);

  /// Every menu item across every merchant (the "Buscar" tab's "Platos"
  /// result mode — design brief §2.9/backlog item 5, cross-merchant dish
  /// search). Unlike [getMerchantTagIdsByMerchant]/[getTagsForMerchant],
  /// this doesn't require an N+1 per-merchant fetch: `GET
  /// /api/v1/menu_items` (confirmed live) already supports listing every
  /// item with no `merchant_id` filter, so [RemoteDataSource] just fetches
  /// every page of that same endpoint.
  Future<List<MenuItem>> getAllMenuItems();

  /// Business hours for a given merchant. May contain more than one row for
  /// the same [BusinessHour.dayOfWeek] (double shift) — see the model doc.
  Future<List<BusinessHour>> getBusinessHours(int merchantId);

  /// Loyalty ladder rules for a given merchant (detail screen's
  /// "Mis visitas" sub-tab).
  Future<List<LoyaltyRule>> getLoyaltyRules(int merchantId);

  /// All tags known to the app (e.g. to render filter options).
  Future<List<Tag>> getTags();

  /// Tags associated with a merchant via `merchants_tags`.
  Future<List<Tag>> getTagsForMerchant(int merchantId);

  /// All `merchants_tags` associations, grouped by merchant id.
  ///
  /// Exists for callers that need to filter/group merchants by tag across
  /// the *whole* merchant list (e.g. the search filters sheet's "dieta"
  /// filter, design brief §2.9) without issuing one [getTagsForMerchant]
  /// call per merchant.
  Future<Map<int, Set<int>>> getMerchantTagIdsByMerchant();

  /// All `business_hours` rows for every merchant, grouped by merchant id.
  ///
  /// Exists for callers that need to know whether merchants are open
  /// *right now* across the whole search result set (the search filters
  /// sheet's "Abierto ahora" filter, design brief §2.9) without issuing one
  /// [getBusinessHours] call per merchant — mirrors
  /// [getMerchantTagIdsByMerchant]'s bulk shape.
  Future<Map<int, List<BusinessHour>>> getBusinessHoursByMerchant();

  /// All `loyalty_rules` rows for every merchant, grouped by merchant id.
  ///
  /// Exists for callers that need to know whether merchants currently have
  /// an earned loyalty reward across the whole search result set (the
  /// search filters sheet's "Solo con premio de fidelización disponible"
  /// filter, design brief §2.9) without issuing one [getLoyaltyRules] call
  /// per merchant — mirrors [getMerchantTagIdsByMerchant]'s bulk shape.
  Future<Map<int, List<LoyaltyRule>>> getLoyaltyRulesByMerchant();

  /// Tags associated with a menu item via `menu_items_tags`.
  Future<List<Tag>> getTagsForMenuItem(int menuItemId);

  /// The demo-logged-in consumer's own profile.
  Future<Consumer> getCurrentConsumer();

  /// The demo consumer's app settings (theme, notifications).
  Future<ConsumerSettings> getConsumerSettings();

  /// The demo consumer's per-merchant visit summaries ("Mis Lugares" /
  /// Visitas sub-tab, and the loyalty hero on the detail screen), optionally
  /// scoped to a single merchant — mirrors [getVisits]'s shape so the detail
  /// screen doesn't have to filter the full list by hand.
  Future<List<VisitSummary>> getVisitSummaries({int? merchantId});

  /// The demo consumer's raw visit history, optionally scoped to a single
  /// merchant (detail screen's visit timeline).
  Future<List<Visit>> getVisits({int? merchantId});

  /// The demo consumer's favorited merchants ("Mis Lugares" / Favoritos).
  Future<List<Favorite>> getFavorites();

  /// Favorites [merchantId] for the demo consumer.
  ///
  /// Takes a **merchant id**, not a favorite id — see [removeFavorite]'s doc
  /// for why the two methods key on different ids.
  Future<void> addFavorite(int merchantId);

  /// Un-favorites [merchantId] for the demo consumer.
  ///
  /// Takes a **merchant id**, for symmetry with [addFavorite] and because
  /// that's what callers (`FavoriteIdsNotifier.toggle`) actually have on
  /// hand. This is a deliberate asymmetry with the real backend, which has
  /// no "delete by merchant_id" route — only `DELETE
  /// /api/v1/favorites/{id}` (the favorite row's own id). [RemoteDataSource]
  /// resolves `merchantId` to a favorite id internally (by looking it up in
  /// the already-cached [getFavorites] list) before issuing the request; see
  /// that implementation's doc for the full explanation.
  Future<void> removeFavorite(int merchantId);

  /// Gift cards sent by the demo consumer ("Regalar" history, if surfaced).
  Future<List<Gift>> getGifts();

  /// Buys and sends a gift card ("Regalar" tab CTA) — the authenticated
  /// consumer is always the sender.
  ///
  /// `expires_at` is a required field on the real API, but the "Regalar" UI
  /// (`features/gifting/gifting_screen.dart`) has no expiration concept
  /// today. **Unconfirmed product decision, taken here for lack of anyone
  /// else to ask**: gift cards default to expiring exactly one year after
  /// purchase (`now + 365 days`), matching common gift-card practice. Revisit
  /// if product ever wants this configurable/visible in the UI.
  Future<Gift> createGift({
    required GiftType type,
    required double amount,
    required String recipientPhone,
    String? message,
  });

  /// The demo consumer's past searches (home screen "Continuar búsqueda").
  Future<List<SearchHistory>> getSearchHistory();

  /// Sends a free-text query to the Gemini-backed natural-language search
  /// parser (`POST /api/v1/search`, `backend/app/services/
  /// search_query_parser.rb`) and returns the structured filters it
  /// derived — the home hero's "AI search" (`features/home/home_screen.dart`),
  /// matching `web/lib/api/search.ts`'s `parseSearchQuery` 1:1. Public on the
  /// real backend (no auth required, see `SearchController`'s own doc
  /// comment) — [RemoteDataSource] makes this call the same way as any other
  /// request; the shared [Dio] client only attaches a bearer token when one
  /// is already stored, so this works fully logged out too.
  Future<SearchQueryFilters> parseSearchQuery(String query);
}
