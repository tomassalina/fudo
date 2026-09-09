import 'package:flutter/foundation.dart';

/// Structured filters the backend's Gemini-backed parser derives from a
/// free-text search query — the `filters` field of `POST /api/v1/search`'s
/// response body (`backend/app/controllers/api/v1/search_controller.rb`,
/// `backend/app/services/search_query_parser.rb`).
///
/// Mirrors `web/lib/api/search.ts`'s `SearchQueryFilters` interface
/// field-for-field, since Flutter's AI search is meant to match web's exact
/// flow: this is the ONLY caller of `POST /api/v1/search` on the Flutter
/// side (`data/remote/remote_data_source.dart`'s `parseSearchQuery`), used
/// exclusively by the home hero's AI search entry point
/// (`features/home/home_screen.dart`). The plain substring filter on the
/// "Buscar" tab (`features/search/widgets/search_utils.dart`'s
/// `filterMerchants`) never touches this endpoint.
@immutable
class SearchQueryFilters {
  const SearchQueryFilters({
    required this.neighborhood,
    required this.type,
    required this.tags,
    required this.pricePerPerson,
    required this.open,
    required this.reward,
    required this.query,
    required this.resultMode,
  });

  /// The neighborhood/area name mentioned in the query, exactly as Gemini
  /// extracted it — or `null` if none was mentioned. Matched against
  /// `Merchant.neighborhood` verbatim server-side, same as web.
  final String? neighborhood;

  /// Raw `merchant_type_enum` string (e.g. `"restaurant"`), or `null` — see
  /// `data/models/merchant.dart`'s `MerchantTypeJson.fromJson` for parsing.
  final String? type;

  /// Diet/cuisine/mood tag names (lowercase, matching `tags.name`).
  final List<String> tags;

  /// A numeric price-per-person estimate/budget, or `null`.
  final double? pricePerPerson;

  /// "Abierto ahora" — no real backend filter behind it yet (see
  /// `SearchQueryParser`'s own doc comment); flows straight through to the
  /// client-side "open now" filter, same as web's `resolve-ai-search.ts`.
  final bool? open;

  /// "Premio por visitas" — same no-backend-filter-yet situation as [open].
  final bool? reward;

  /// Free-text fragment naming a specific dish/ingredient or merchant that
  /// doesn't map to [type]/[tags] (e.g. "milanesa", "la parrilla de
  /// Borges") — maps onto the search screen's own free-text query, which
  /// already matches names/dishes locally (`search_utils.dart`'s
  /// `filterMerchants` / `dish_results_list.dart`). This parser never
  /// matches it against anything itself.
  final String? query;

  /// Whether [query] is about a PLACE (`"lugares"`) or a DISH (`"platos"`)
  /// — maps onto the search screen's Lugares/Platos result-mode toggle.
  final String? resultMode;

  factory SearchQueryFilters.fromJson(Map<String, dynamic> json) {
    return SearchQueryFilters(
      neighborhood: json['neighborhood'] as String?,
      type: json['type'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      pricePerPerson: (json['price_per_person'] as num?)?.toDouble(),
      open: json['open'] as bool?,
      reward: json['reward'] as bool?,
      query: json['query'] as String?,
      resultMode: json['result_mode'] as String?,
    );
  }
}
