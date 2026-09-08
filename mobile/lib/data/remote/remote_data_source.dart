import 'package:dio/dio.dart';

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
import '../models/tag.dart';
import '../models/visit.dart';
import '../models/visit_summary.dart';

/// [DataSource] implementation that talks to the real backend API described
/// in `PLAN.md` Fase 3, over the [Dio] client built by
/// `core/config/dio_client.dart`.
///
/// ⚠️⚠️ IMPORTANT — NOT TESTED AGAINST A REAL BACKEND ⚠️⚠️
/// As of this writing, the backend reachable at `http://localhost:3000`
/// does NOT implement any `/api/v1/*` endpoint yet — only Rails' default
/// `/up` health check responds; `GET /api/v1/merchants` and
/// `POST /api/v1/sessions` both 404. Fase 3 (the API) has not shipped/merged
/// anywhere yet. This class is written strictly against the contract
/// documented in `PLAN.md` Fase 3 ("Endpoints mínimos"), but nothing here
/// has ever been exercised against a running server. Do not treat any of
/// this as verified behavior until Fase 3 ships and Fase 5's manual/E2E pass
/// actually runs against it.
///
/// It's also unreachable from the running app today: [DataSource] selection
/// happens in `data/providers.dart` via `connectionMode`
/// (`data/connection_mode.dart`), whose default is `local` — i.e.
/// `LocalDataSource`. Only an explicit
/// `--dart-define=CONNECTION_MODE=remote` switches to this class.
///
/// Routes explicitly listed in `PLAN.md` Fase 3 §"Endpoints mínimos":
///   `GET  /merchants`, `GET  /merchants/:id`, `GET  /merchants/:id/menu_items`
///   `GET  /me`
///   `GET  /me/visit_summaries`
///   `GET  /me/favorites` (and `POST`/`DELETE /favorites`, not part of
///     [DataSource] — see note on `AuthRepository`-style split)
///   `GET  /me/gifts` (and `POST /gifts`, same note)
///   `GET  /me/search_history`
///
/// Every other method below hits a route `PLAN.md` does not explicitly
/// define; each carries a `// TODO(fase-4): confirmar contra la API real`
/// comment marking the guessed REST convention — none of these are
/// confirmed, they're a reasonable-best-effort placeholder.
class RemoteDataSource implements DataSource {
  RemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    final data = response.data ?? const <dynamic>[];
    return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Merchant>> getMerchants() {
    return _getList('/merchants', Merchant.fromJson);
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
    return _getList('/merchants/$merchantId/menu_items', MenuItem.fromJson);
  }

  // TODO(fase-4): confirmar contra la API real — PLAN.md no define un
  // endpoint de business_hours explícito; se asume la misma convención
  // anidada que `menu_items`.
  @override
  Future<List<BusinessHour>> getBusinessHours(int merchantId) {
    return _getList(
      '/merchants/$merchantId/business_hours',
      BusinessHour.fromJson,
    );
  }

  // TODO(fase-4): confirmar contra la API real — mismo caso que
  // getBusinessHours, PLAN.md no lo define explícitamente.
  @override
  Future<List<LoyaltyRule>> getLoyaltyRules(int merchantId) {
    return _getList(
      '/merchants/$merchantId/loyalty_rules',
      LoyaltyRule.fromJson,
    );
  }

  // TODO(fase-4): confirmar contra la API real — PLAN.md no menciona un
  // endpoint global de tags; se asume uno de solo lectura para poblar
  // filtros (design brief §2.9).
  @override
  Future<List<Tag>> getTags() {
    return _getList('/tags', Tag.fromJson);
  }

  // TODO(fase-4): confirmar contra la API real.
  @override
  Future<List<Tag>> getTagsForMerchant(int merchantId) {
    return _getList('/merchants/$merchantId/tags', Tag.fromJson);
  }

  // TODO(fase-4): confirmar contra la API real — no hay endpoint de bulk
  // merchant→tags en PLAN.md. Se asume que el backend expone la tabla de
  // join `merchants_tags` completa como lista de `{merchant_id, tag_id}`;
  // si no existe, esto probablemente termine reemplazado por N llamadas a
  // `getTagsForMerchant` o por un endpoint dedicado una vez que Fase 3 esté
  // documentada con OpenAPI/rswag.
  @override
  Future<Map<int, Set<int>>> getMerchantTagIdsByMerchant() async {
    final response = await _dio.get<List<dynamic>>('/merchants_tags');
    final data = response.data ?? const <dynamic>[];
    final result = <int, Set<int>>{};
    for (final row in data) {
      final map = row as Map<String, dynamic>;
      final merchantId = map['merchant_id'] as int;
      final tagId = map['tag_id'] as int;
      result.putIfAbsent(merchantId, () => <int>{}).add(tagId);
    }
    return result;
  }

  // TODO(fase-4): confirmar contra la API real.
  @override
  Future<List<Tag>> getTagsForMenuItem(int menuItemId) {
    return _getList('/menu_items/$menuItemId/tags', Tag.fromJson);
  }

  @override
  Future<Consumer> getCurrentConsumer() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return Consumer.fromJson(response.data!);
  }

  // TODO(fase-4): confirmar contra la API real — PLAN.md solo lista
  // `GET /me` / `PATCH /me` para el perfil, sin un endpoint separado de
  // settings; se asume que vive anidado bajo `/me`.
  @override
  Future<ConsumerSettings> getConsumerSettings() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/settings');
    return ConsumerSettings.fromJson(response.data!);
  }

  @override
  Future<List<VisitSummary>> getVisitSummaries({int? merchantId}) {
    return _getList(
      '/me/visit_summaries',
      VisitSummary.fromJson,
      queryParameters: merchantId == null
          ? null
          : {'merchant_id': merchantId},
    );
  }

  // TODO(fase-4): confirmar contra la API real — PLAN.md solo lista
  // `GET /me/visit_summaries`, no un endpoint de visitas crudas; se asume
  // la misma convención bajo `/me`.
  @override
  Future<List<Visit>> getVisits({int? merchantId}) {
    return _getList(
      '/me/visits',
      Visit.fromJson,
      queryParameters: merchantId == null
          ? null
          : {'merchant_id': merchantId},
    );
  }

  @override
  Future<List<Favorite>> getFavorites() {
    return _getList('/me/favorites', Favorite.fromJson);
  }

  @override
  Future<List<Gift>> getGifts() {
    return _getList('/me/gifts', Gift.fromJson);
  }

  @override
  Future<List<SearchHistory>> getSearchHistory() {
    return _getList('/me/search_history', SearchHistory.fromJson);
  }
}
