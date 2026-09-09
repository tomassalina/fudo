import 'package:dio/dio.dart';

import '../auth/current_consumer_session.dart';
import '../data_source.dart';
import '../models/business_hour.dart';
import '../models/consumer.dart';
import '../models/consumer_settings.dart';
import '../models/favorite.dart';
import '../models/gift.dart';
import '../models/loyalty_rule.dart';
import '../models/menu_item.dart';
import '../models/merchant.dart';
import '../models/search_history.dart';
import '../models/search_query_filters.dart';
import '../models/tag.dart';
import '../models/visit.dart';
import '../models/visit_summary.dart';

/// [DataSource] implementation that talks to the real backend API, over the
/// [Dio] client built by `core/config/dio_client.dart`.
///
/// Written and verified live against the Rails backend running at
/// `http://localhost:3000` (30 seeded merchants in Palermo) — every route
/// below was either confirmed against a real `curl` response, or against the
/// generated OpenAPI doc served at `GET /api-docs/v1/swagger.yaml`, which is
/// the source of truth (NOT `PLAN.md`, which predates this backend and is
/// wrong on several endpoint shapes — kept only where it happens to still
/// match). See `test/integration/remote_data_source_live_test.dart` for an
/// end-to-end test that exercises this class against the real server.
///
/// Two API-wide quirks every method here has to account for:
/// - **Pagination**: every list endpoint returns `{"data": [...], "meta":
///   {"current_page", "total_pages", "total_count", "per_page"}}`, capped at
///   20 items per page by default. [DataSource]'s contract (matching
///   `LocalDataSource`) is "give me everything", so [_getAllPages] loops
///   until `current_page == total_pages` and concatenates.
/// - **Numeric fields as strings**: `latitude`/`longitude`/
///   `price_per_person_min/max` (merchants), `price` (menu items) and
///   `amount` (gifts) are serialized as JSON strings, not numbers (Postgres
///   `numeric`/`decimal` columns, to avoid float precision loss). This is
///   handled inside `Merchant.fromJson`/`MenuItem.fromJson`/`Gift.fromJson`
///   themselves (a JSON-parsing concern, not a remote-vs-local one), not
///   here.
///
/// [connectionMode] (`data/connection_mode.dart`) still defaults to `local`
/// — this class is only reachable with an explicit
/// `--dart-define=CONNECTION_MODE=remote`.
class RemoteDataSource implements DataSource {
  RemoteDataSource(this._dio, {required this._consumerSession});

  final Dio _dio;

  /// Shared with `AuthRepository` (see `data/providers.dart`) so a
  /// successful `AuthRepository.login()`/`register()` call is visible to
  /// [getCurrentConsumer] here. See [CurrentConsumerSession]'s doc for why
  /// this exists at all (there is no "get my own profile" endpoint).
  final CurrentConsumerSession _consumerSession;

  /// Fetches every page of a paginated list endpoint and concatenates the
  /// results, so callers get the same "just give me everything" shape
  /// `LocalDataSource` provides. Loops until the response's `meta` reports
  /// `current_page == total_pages`.
  Future<List<T>> _getAllPages<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final results = <T>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {...?queryParameters, 'page': page},
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = (body['data'] as List<dynamic>?) ?? const <dynamic>[];
      results.addAll(data.map((e) => fromJson(e as Map<String, dynamic>)));

      final meta = body['meta'] as Map<String, dynamic>?;
      final currentPage = meta?['current_page'] as int? ?? page;
      final totalPages = meta?['total_pages'] as int? ?? page;
      if (currentPage >= totalPages) break;
      page = currentPage + 1;
    }
    return results;
  }

  @override
  Future<List<Merchant>> getMerchants() {
    return _getAllPages('/merchants', Merchant.fromJson);
  }

  @override
  Future<Merchant?> getMerchant(int merchantId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/merchants/$merchantId',
      );
      final data = response.data;
      return data == null ? null : Merchant.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<MenuItem>> getMenuItems(int merchantId) {
    return _getAllPages(
      '/menu_items',
      MenuItem.fromJson,
      queryParameters: {'merchant_id': merchantId},
    );
  }

  /// Same `GET /menu_items` route as [getMenuItems], just without the
  /// `merchant_id` filter — confirmed live that the endpoint lists every
  /// merchant's items when it's omitted (150 items across 30 seeded
  /// merchants at the time of writing), so this is one paginated fetch, not
  /// an N+1 fan-out per merchant.
  @override
  Future<List<MenuItem>> getAllMenuItems() {
    return _getAllPages('/menu_items', MenuItem.fromJson);
  }

  @override
  Future<List<BusinessHour>> getBusinessHours(int merchantId) {
    return _getAllPages(
      '/business_hours',
      BusinessHour.fromJson,
      queryParameters: {'merchant_id': merchantId},
    );
  }

  /// Same `GET /business_hours` route as [getBusinessHours], just without
  /// the `merchant_id` filter. Unlike [getMerchantTagIdsByMerchant], this is
  /// a genuine bulk fetch, not an N+1 fan-out: the backend's
  /// `filtered_business_hours` (`backend/app/controllers/api/v1/
  /// business_hours_controller.rb`) only scopes by `merchant_id` when the
  /// param is present, so omitting it returns every merchant's rows in one
  /// paginated fetch — confirmed against the live backend, along with
  /// [getLoyaltyRulesByMerchant]'s sibling method.
  @override
  Future<Map<int, List<BusinessHour>>> getBusinessHoursByMerchant() async {
    final hours = await _getAllPages('/business_hours', BusinessHour.fromJson);
    final result = <int, List<BusinessHour>>{};
    for (final hour in hours) {
      result.putIfAbsent(hour.merchantId, () => <BusinessHour>[]).add(hour);
    }
    return result;
  }

  @override
  Future<List<LoyaltyRule>> getLoyaltyRules(int merchantId) {
    return _getAllPages(
      '/loyalty_rules',
      LoyaltyRule.fromJson,
      queryParameters: {'merchant_id': merchantId},
    );
  }

  /// Same `GET /loyalty_rules` route as [getLoyaltyRules], just without the
  /// `merchant_id` filter — see [getBusinessHoursByMerchant]'s doc for why
  /// this is a genuine single bulk fetch (the backend's
  /// `filtered_loyalty_rules` has the identical "scope by merchant_id only
  /// when present" shape).
  @override
  Future<Map<int, List<LoyaltyRule>>> getLoyaltyRulesByMerchant() async {
    final rules = await _getAllPages('/loyalty_rules', LoyaltyRule.fromJson);
    final result = <int, List<LoyaltyRule>>{};
    for (final rule in rules) {
      result.putIfAbsent(rule.merchantId, () => <LoyaltyRule>[]).add(rule);
    }
    return result;
  }

  @override
  Future<List<Tag>> getTags() {
    return _getAllPages('/tags', Tag.fromJson);
  }

  /// `GET /merchants/:id` (the bare/show route, confirmed via the OpenAPI
  /// doc and live `curl`) embeds `tags` as an array of tag **names**
  /// (`["sin_tacc", "apto_celiacos", ...]`), not `{id, name}` objects, and
  /// there is no separate `GET /merchants/:id/tags` route. To return real
  /// [Tag] objects (with ids) as [DataSource] promises, this fetches the
  /// merchant's tag names and [getTags]'s full catalog, then cross-references
  /// by name. A name that doesn't match any known [Tag] (shouldn't happen,
  /// but the two calls aren't transactional) is silently dropped rather than
  /// crashing the whole list.
  @override
  Future<List<Tag>> getTagsForMerchant(int merchantId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/merchants/$merchantId',
    );
    final tagNames =
        (response.data?['tags'] as List<dynamic>?)?.cast<String>() ??
        const <String>[];
    if (tagNames.isEmpty) return const [];
    final allTags = await getTags();
    final byName = {for (final tag in allTags) tag.name: tag};
    return tagNames.map((name) => byName[name]).whereType<Tag>().toList();
  }

  // TODO(fase-4): the real API has no bulk merchant→tag endpoint (no
  // `/merchants_tags` route at all) — the only way to learn a merchant's
  // tags is `GET /merchants/:id`, one merchant at a time. Building the
  // map this method promises therefore costs one request per merchant
  // (N+1, N = merchant count) plus one `GET /tags` to resolve tag names to
  // ids. For today's 30 seeded merchants that's an acceptable one-off cost
  // for populating the search filters sheet, but this does NOT scale — if
  // the merchant catalog grows meaningfully, this needs a real bulk
  // endpoint from the backend instead of silently eating N requests here.
  @override
  Future<Map<int, Set<int>>> getMerchantTagIdsByMerchant() async {
    final merchants = await getMerchants();
    final allTags = await getTags();
    final idByName = {for (final tag in allTags) tag.name: tag.id};

    final result = <int, Set<int>>{};
    for (final merchant in merchants) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/merchants/${merchant.id}',
      );
      final tagNames =
          (response.data?['tags'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];
      result[merchant.id] = tagNames
          .map((name) => idByName[name])
          .whereType<int>()
          .toSet();
    }
    return result;
  }

  /// `GET /menu_items/:id` (confirmed via live `curl`) embeds `tags` the
  /// same way `GET /merchants/:id` does — an array of names, cross-referenced
  /// against [getTags] the same way [getTagsForMerchant] does. See that
  /// method's doc for the name-matching caveat.
  @override
  Future<List<Tag>> getTagsForMenuItem(int menuItemId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/menu_items/$menuItemId',
    );
    final tagNames =
        (response.data?['tags'] as List<dynamic>?)?.cast<String>() ??
        const <String>[];
    if (tagNames.isEmpty) return const [];
    final allTags = await getTags();
    final byName = {for (final tag in allTags) tag.name: tag};
    return tagNames.map((name) => byName[name]).whereType<Tag>().toList();
  }

  /// There is no `GET`-your-own-profile endpoint anywhere in the real API
  /// (confirmed against the live OpenAPI doc — see
  /// `CurrentConsumerSession`'s doc for the full explanation). This reads
  /// the snapshot [AuthRepository] stored after a successful
  /// `login()`/`register()` instead of calling the network at all.
  ///
  /// Throws [StateError] if nobody has logged in yet this app session —
  /// callers must not treat that as "no consumer", since a demo/authed flow
  /// should always log in first.
  @override
  Future<Consumer> getCurrentConsumer() async {
    final consumer = _consumerSession.consumer;
    if (consumer == null) {
      throw StateError(
        'RemoteDataSource.getCurrentConsumer() was called without an '
        'active login in this app session. The real API has no endpoint to '
        'fetch "my own profile" — the only source of a full Consumer object '
        'is the response of POST /sessions or POST /registrations. Call '
        'AuthRepository.login() (or .register()) first.',
      );
    }
    return consumer;
  }

  /// `GET /consumer_settings` (no `/me` prefix — it auto-scopes to the
  /// authenticated consumer) returns `data` as an array of **0 or 1**
  /// elements, not a bare object (confirmed via live `curl` and the OpenAPI
  /// doc) — a brand-new consumer has no `ConsumerSettings` row yet (it's
  /// created lazily via `POST`, not at registration time), so the array can
  /// legitimately come back empty. Rather than crash the settings screen for
  /// that consumer, this falls back to sane defaults (system theme,
  /// notifications on) with `id: 0` marking "not yet persisted on the
  /// backend" instead of a real row id.
  @override
  Future<ConsumerSettings> getConsumerSettings() async {
    final response = await _dio.get<Map<String, dynamic>>('/consumer_settings');
    final data =
        (response.data?['data'] as List<dynamic>?) ?? const <dynamic>[];
    if (data.isEmpty) {
      return ConsumerSettings(
        id: 0,
        consumerId: _consumerSession.consumer?.id ?? '',
        theme: ThemePreference.system,
        notificationsEnabled: true,
      );
    }
    return ConsumerSettings.fromJson(data.first as Map<String, dynamic>);
  }

  /// `GET /visit_summaries` does **not** support a `?merchant_id=` filter —
  /// confirmed live: passing it still returns every merchant's summary
  /// (unlike `business_hours`/`loyalty_rules`/`menu_items`, which do filter
  /// server-side). So this fetches every page and filters client-side
  /// instead of trusting a query parameter the backend silently ignores.
  @override
  Future<List<VisitSummary>> getVisitSummaries({int? merchantId}) async {
    final summaries = await _getAllPages(
      '/visit_summaries',
      VisitSummary.fromJson,
    );
    if (merchantId == null) return summaries;
    return summaries.where((s) => s.merchantId == merchantId).toList();
  }

  /// Same server-side filter gap as [getVisitSummaries] — confirmed live
  /// that `GET /visits?merchant_id=` is ignored — so this filters
  /// client-side after fetching every page.
  @override
  Future<List<Visit>> getVisits({int? merchantId}) async {
    final visits = await _getAllPages('/visits', Visit.fromJson);
    if (merchantId == null) return visits;
    return visits.where((v) => v.merchantId == merchantId).toList();
  }

  @override
  Future<List<Favorite>> getFavorites() {
    return _getAllPages('/favorites', Favorite.fromJson);
  }

  /// `POST /api/v1/favorites`, body `{"favorite": {"merchant_id": N}}`
  /// (confirmed via the OpenAPI doc). `consumer_id` always comes from the
  /// authenticated consumer server-side, never from client input. 201 on
  /// success; 422 if this merchant is already favorited by this consumer
  /// (duplicate `consumer_id`/`merchant_id` pair) — left as a thrown
  /// [DioException] for the caller ([FavoriteIdsNotifier.toggle]) to decide
  /// what to do with, same as every other write in this app.
  @override
  Future<void> addFavorite(int merchantId) async {
    await _dio.post<Map<String, dynamic>>(
      '/favorites',
      data: {
        'favorite': {'merchant_id': merchantId},
      },
    );
  }

  /// **Asymmetric with [addFavorite] on purpose** — the real API has no
  /// "delete by merchant_id" route, only `DELETE /api/v1/favorites/{id}`
  /// (confirmed via the OpenAPI doc), keyed on the favorite row's own `id`,
  /// not `merchant_id`. So this first calls [getFavorites] to find the
  /// favorite whose `merchant_id` matches, then deletes it by its `id`. If
  /// no matching favorite is cached (already removed, or never favorited),
  /// this is a no-op rather than an error — mirrors [addFavorite]'s
  /// duplicate-is-fine posture from the other direction.
  ///
  /// Confirmed live: `DELETE /favorites/{id}` returns `204 No Content` (a
  /// soft-delete server-side) with no response body.
  @override
  Future<void> removeFavorite(int merchantId) async {
    final favorites = await getFavorites();
    final favorite = favorites.cast<Favorite?>().firstWhere(
      (f) => f?.merchantId == merchantId,
      orElse: () => null,
    );
    if (favorite == null) return;
    await _dio.delete<void>('/favorites/${favorite.id}');
  }

  /// `GET /api/v1/gifts` (confirmed live) omits `recipient_phone`/`message`
  /// from every row — [Gift.fromJson] defaults `recipientPhone` to `''` for
  /// exactly that reason (see that class's doc comment). Don't rely on
  /// either field being meaningful on a [Gift] that came from this method;
  /// they're only real on the object [createGift] returns from the 201.
  @override
  Future<List<Gift>> getGifts() {
    return _getAllPages('/gifts', Gift.fromJson);
  }

  /// `POST /api/v1/gifts`, body `{"gift": {"type", "amount",
  /// "recipient_phone", "expires_at", "message"?}}` (confirmed via the
  /// OpenAPI doc). `sender_consumer_id` always comes from the authenticated
  /// consumer server-side — this never sends `recipient_consumer_id`, since
  /// the "Regalar" UI only ever collects a phone number, not a consumer id.
  /// 201 on success, parsed straight into a [Gift]; 422 (validation errors,
  /// per the OpenAPI doc) is left as a thrown [DioException] for the caller
  /// to decide what to do with, same posture as [addFavorite].
  ///
  /// See [DataSource.createGift]'s doc for the `expires_at` default — this
  /// method itself just sends whatever `expiresAt` it's given the ISO 8601
  /// way the API expects.
  @override
  Future<Gift> createGift({
    required GiftType type,
    required double amount,
    required String recipientPhone,
    String? message,
  }) async {
    final expiresAt = DateTime.now().add(const Duration(days: 365));
    final response = await _dio.post<Map<String, dynamic>>(
      '/gifts',
      data: {
        'gift': {
          'type': type.toJson(),
          'amount': amount,
          'recipient_phone': recipientPhone,
          'expires_at': expiresAt.toIso8601String(),
          'message': ?message,
        },
      },
    );
    return Gift.fromJson(response.data!);
  }

  @override
  Future<List<SearchHistory>> getSearchHistory() {
    return _getAllPages('/search_histories', SearchHistory.fromJson);
  }

  /// `POST /api/v1/search`, body `{"query": "<free text>"}` (confirmed live
  /// via `curl` — see `search_controller.rb`/`search_query_parser.rb`).
  /// Public/unauthenticated by product rule: no `authenticate_consumer!` on
  /// the controller, so this call needs no special no-auth handling — the
  /// shared [Dio] instance's request interceptor (`core/config/
  /// dio_client.dart`) already only attaches `Authorization` when
  /// [TokenStorage.readToken] actually has a token, exactly the same
  /// "attach if present, omit otherwise" behavior `web/lib/api/search.ts`
  /// documents for its own `authHeader()` call. The response also embeds
  /// `data`/`meta` (matched merchants + pagination) alongside `filters`, but
  /// those are deliberately unused here for the same reason web's
  /// `parseSearchQuery` ignores them: the search screen re-derives its own
  /// result set from `filters` via the existing merchant list/filter
  /// pipeline (`applySearchFilters`/`filterMerchants`), not a second,
  /// parallel result set that never went through it.
  @override
  Future<SearchQueryFilters> parseSearchQuery(String query) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/search',
      data: {'query': query},
    );
    final filters = response.data?['filters'] as Map<String, dynamic>?;
    return SearchQueryFilters.fromJson(filters ?? const {});
  }
}
