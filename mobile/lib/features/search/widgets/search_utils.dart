import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formatting/currency_format.dart';
import '../../../core/location/location_service.dart';
import '../../../data/models/business_hour.dart';
import '../../../data/models/loyalty_rule.dart';
import '../../../data/models/merchant.dart';
import '../../../data/models/search_query_filters.dart';
import '../../../data/models/tag.dart';

/// Shared filtering/formatting helpers for the search results list and map
/// views, so both stay in sync on what counts as "matching the query" and
/// how a merchant's distance/price are rendered.

const Distance _distanceCalculator = Distance();

const Map<String, String> _accentMap = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
};

/// Lowercases and strips Spanish diacritics so "café" and "Café" both match
/// "cafe".
String normalizeForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentMap[char] ?? char);
  }
  return buffer.toString();
}

/// Spanish display label for a [MerchantType], used only for text matching
/// here (the visual badge is icon+color, see [MerchantTypePresentation]).
String merchantTypeLabel(MerchantType type) => switch (type) {
  MerchantType.restaurant => 'Restaurante',
  MerchantType.cafe => 'Café',
  MerchantType.bar => 'Bar',
  MerchantType.darkKitchen => 'Dark kitchen',
  MerchantType.pizzeria => 'Pizzería',
  MerchantType.brewery => 'Cervecería',
  MerchantType.foodTruck => 'Food truck',
  MerchantType.other => 'Otro',
};

/// Client-side text filter used by both the results list and the map view.
///
/// This is a simple case- and accent-insensitive substring match against
/// name/type/neighborhood — good enough for this stage. Real intent-based
/// matching (e.g. "picante"/"vegano" against tags, as in the design
/// prototype's regex-driven `AI` matcher) is a future improvement; we don't
/// build that full engine here.
List<Merchant> filterMerchants(List<Merchant> merchants, String query) {
  final normalizedQuery = normalizeForSearch(query.trim());
  if (normalizedQuery.isEmpty) return merchants;
  return merchants.where((merchant) {
    final haystack = normalizeForSearch(
      [
        merchant.name,
        merchantTypeLabel(merchant.type),
        merchant.neighborhood ?? '',
      ].join(' '),
    );
    return haystack.contains(normalizedQuery);
  }).toList();
}

/// Distance in kilometers from the user to [merchant].
///
/// Uses the real device location once the user has activated it (see
/// `core/location/location_service.dart`'s [userLocationController]) —
/// falling back to [AppConstants.defaultMapCenter] (a simulated location)
/// while it hasn't been requested yet, or when permission was denied/the
/// platform call failed, so every merchant still has *a* distance to show.
double distanceKmFromUser(Merchant merchant) => _distanceCalculator.as(
  LengthUnit.Kilometer,
  userLocationController.value ?? AppConstants.defaultMapCenter,
  LatLng(merchant.latitude, merchant.longitude),
);

/// Human-readable distance: meters under 1km, one decimal of km otherwise.
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Formats a price-per-person range as a chip label (e.g. "\$29.500 –
/// \$54.500"), or `null` if the merchant has no price data at all.
String? formatPriceRange(Merchant merchant) {
  final min = merchant.pricePerPersonMin;
  final max = merchant.pricePerPersonMax;
  if (min == null && max == null) return null;
  if (min != null && max != null) {
    return '${formatMoney(min)} – ${formatMoney(max)}';
  }
  return formatMoney(min ?? max!);
}

/// Formats a raw amount as Argentine-style money (e.g. "$29.500"). Public so
/// the filters sheet can label its price `RangeSlider` with the same format
/// used on merchant cards. Delegates to the shared
/// `core/formatting/currency_format.dart` implementation.
String formatMoney(double value) => formatCurrency(value);

// ---------------------------------------------------------------------------
// Advanced filters (design brief §2.9)
// ---------------------------------------------------------------------------

/// Sort options for the "Básico" filter category.
enum SortOption { relevance, distance, price, mostVisited }

/// Spanish display label for a [SortOption].
extension SortOptionLabel on SortOption {
  String get label => switch (this) {
    SortOption.relevance => 'Relevancia',
    SortOption.distance => 'Distancia',
    SortOption.price => 'Precio',
    SortOption.mostVisited => 'Más visitados',
  };
}

/// Immutable snapshot of everything selected in the advanced filters sheet
/// (`filters_sheet.dart`, design brief §2.9).
///
/// [openNowOnly] and [rewardAvailableOnly] are both applied by
/// [applySearchFilters], using the bulk `businessHoursByMerchant`/
/// `loyaltyRulesByMerchant` maps (`data/providers.dart`) so checking either
/// across the whole result set costs one request total, not one per
/// merchant — see `DataSource.getBusinessHoursByMerchant`/
/// `DataSource.getLoyaltyRulesByMerchant`.
@immutable
class SearchFilters {
  const SearchFilters({
    this.sort = SortOption.relevance,
    this.merchantType,
    this.openNowOnly = false,
    this.minPricePerPerson,
    this.maxPricePerPerson,
    this.dietTagIds = const <int>{},
    this.neighborhood,
    this.maxDistanceKm,
    this.rewardAvailableOnly = false,
    this.hideVisited = false,
  });

  final SortOption sort;
  final MerchantType? merchantType;
  final bool openNowOnly;
  final double? minPricePerPerson;
  final double? maxPricePerPerson;
  final Set<int> dietTagIds;
  final String? neighborhood;
  final double? maxDistanceKm;
  final bool rewardAvailableOnly;
  final bool hideVisited;

  /// Number of *categories* with a non-default selection — matches the
  /// design brief's "1 filtro activo"/"{n} filtros activos" copy on the
  /// sheet's "Aplicar" button. A multi-select category (e.g. picking 3 diet
  /// tags) still counts once, since it represents one filtering decision
  /// ("dieta"), not three.
  int get activeCount {
    var count = 0;
    if (sort != SortOption.relevance) count++;
    if (merchantType != null) count++;
    if (openNowOnly) count++;
    if (minPricePerPerson != null || maxPricePerPerson != null) count++;
    if (dietTagIds.isNotEmpty) count++;
    if (neighborhood != null) count++;
    if (maxDistanceKm != null) count++;
    if (rewardAvailableOnly) count++;
    if (hideVisited) count++;
    return count;
  }

  /// `merchantType`/`neighborhood` need to go from "selected" back to "no
  /// selection" (tapping the same chip again) — a plain positional override
  /// can't tell "leave as-is" apart from "clear it", so those two take an
  /// optional value-returning function instead (`() => null` clears it).
  SearchFilters copyWith({
    SortOption? sort,
    ValueGetter<MerchantType?>? merchantType,
    bool? openNowOnly,
    double? minPricePerPerson,
    double? maxPricePerPerson,
    Set<int>? dietTagIds,
    ValueGetter<String?>? neighborhood,
    double? maxDistanceKm,
    bool? rewardAvailableOnly,
    bool? hideVisited,
  }) {
    return SearchFilters(
      sort: sort ?? this.sort,
      merchantType: merchantType != null ? merchantType() : this.merchantType,
      openNowOnly: openNowOnly ?? this.openNowOnly,
      minPricePerPerson: minPricePerPerson ?? this.minPricePerPerson,
      maxPricePerPerson: maxPricePerPerson ?? this.maxPricePerPerson,
      dietTagIds: dietTagIds ?? this.dietTagIds,
      neighborhood: neighborhood != null ? neighborhood() : this.neighborhood,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      rewardAvailableOnly: rewardAvailableOnly ?? this.rewardAvailableOnly,
      hideVisited: hideVisited ?? this.hideVisited,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchFilters &&
        other.sort == sort &&
        other.merchantType == merchantType &&
        other.openNowOnly == openNowOnly &&
        other.minPricePerPerson == minPricePerPerson &&
        other.maxPricePerPerson == maxPricePerPerson &&
        setEquals(other.dietTagIds, dietTagIds) &&
        other.neighborhood == neighborhood &&
        other.maxDistanceKm == maxDistanceKm &&
        other.rewardAvailableOnly == rewardAvailableOnly &&
        other.hideVisited == hideVisited;
  }

  @override
  int get hashCode => Object.hash(
    sort,
    merchantType,
    openNowOnly,
    minPricePerPerson,
    maxPricePerPerson,
    Object.hashAllUnordered(dietTagIds),
    neighborhood,
    maxDistanceKm,
    rewardAvailableOnly,
    hideVisited,
  );
}

/// Whether a merchant is open right now, given its full `business_hours`
/// list and the current wall-clock time.
///
/// Mirrors `restaurant_detail_screen.dart`'s `_computeOpenStatus` open/closed
/// algorithm exactly (same day-of-week lookup, "doble turno" — more than one
/// row for the same day — and overnight-shift handling): a merchant can have
/// more than one row for today, so every non-closed row is checked, not just
/// the first; `closes_at == "00:00:00"` reads as "open until the end of
/// today" (minute 1440), not as wrapping into tomorrow; and a row that
/// genuinely spans past midnight (e.g. opens 22:00, closes 02:00) is looked
/// up as *yesterday's* row when checking whether we're still inside an
/// overnight shift early this morning. Duplicated rather than shared because
/// that helper is private to the detail screen and returns extra UI-only
/// data (`todayHours`) this filter doesn't need.
bool isOpenNow(List<BusinessHour> hours, DateTime now) {
  final today = _weekOrder[now.weekday - 1];
  final yesterday = _weekOrder[(now.weekday - 2 + 7) % 7];
  final nowMinutes = now.hour * 60 + now.minute;

  for (final hour in hours.where((h) => h.dayOfWeek == today)) {
    if (hour.closed) continue;
    final opens = _parseHHmmToMinutes(hour.opensAt);
    final closes = _parseHHmmToMinutes(hour.closesAt);
    if (opens == null || closes == null) continue;
    final effectiveCloses = closes <= opens ? 1440 : closes;
    if (nowMinutes >= opens && nowMinutes < effectiveCloses) return true;
  }

  for (final hour in hours.where((h) => h.dayOfWeek == yesterday)) {
    if (hour.closed) continue;
    final opens = _parseHHmmToMinutes(hour.opensAt);
    final closes = _parseHHmmToMinutes(hour.closesAt);
    if (opens == null || closes == null) continue;
    final wrapsPastMidnight = closes > 0 && closes <= opens;
    if (wrapsPastMidnight && nowMinutes < closes) return true;
  }

  return false;
}

const List<DayOfWeek> _weekOrder = [
  DayOfWeek.monday,
  DayOfWeek.tuesday,
  DayOfWeek.wednesday,
  DayOfWeek.thursday,
  DayOfWeek.friday,
  DayOfWeek.saturday,
  DayOfWeek.sunday,
];

int? _parseHHmmToMinutes(String? hhmmss) {
  if (hhmmss == null) return null;
  final parts = hhmmss.split(':');
  if (parts.length < 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  return hours * 60 + minutes;
}

/// Whether the consumer has already earned at least one loyalty reward at
/// this merchant, given its full `loyalty_rules` ladder and the consumer's
/// visit [count].
///
/// The app has no "claimed" concept for loyalty rewards — `Visit
/// .reward_applied` stays `false` forever server-side (never set by any real
/// flow, per `backend/app/controllers/api/v1/visits_controller.rb`) — so
/// "available" simply mirrors `restaurant_detail_screen.dart`'s
/// `_LoyaltyContent` "reached a rung on the ladder" reading: some rule's
/// `visitsRequired <= count`.
bool hasAvailableReward(List<LoyaltyRule> rules, int count) {
  return rules.any((rule) => count >= rule.visitsRequired);
}

/// Applies [filters] on top of a list already narrowed by [filterMerchants]'
/// free-text query — this is an extension of that filter, not a parallel
/// system.
///
/// [merchantTagIds] is `merchantTagIdsProvider`'s value (merchant id → its
/// tag ids), used for the "dieta" filter. [visitCountsByMerchant] is derived
/// from `visitSummariesProvider(null)` (merchant id → visit count), used for
/// "Ocultar visitados", "Solo con premio de fidelización disponible" and the
/// "Más visitados" sort. [businessHoursByMerchant] is
/// `businessHoursByMerchantProvider`'s value, used for "Abierto ahora" (via
/// [isOpenNow], evaluated against [now], which defaults to `DateTime.now()`
/// — overridable so this stays deterministic in tests).
/// [loyaltyRulesByMerchant] is `loyaltyRulesByMerchantProvider`'s value, used
/// for "Solo con premio de fidelización disponible" (via
/// [hasAvailableReward]). All maps default to empty so this stays callable
/// before those providers resolve — filters that need them simply have no
/// effect yet in that window.
List<Merchant> applySearchFilters(
  List<Merchant> merchants,
  SearchFilters filters, {
  Map<int, Set<int>> merchantTagIds = const {},
  Map<int, int> visitCountsByMerchant = const {},
  Map<int, List<BusinessHour>> businessHoursByMerchant = const {},
  Map<int, List<LoyaltyRule>> loyaltyRulesByMerchant = const {},
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final result = merchants.where((merchant) {
    if (filters.merchantType != null &&
        merchant.type != filters.merchantType) {
      return false;
    }
    if (filters.neighborhood != null &&
        merchant.neighborhood != filters.neighborhood) {
      return false;
    }
    if (filters.maxDistanceKm != null &&
        distanceKmFromUser(merchant) > filters.maxDistanceKm!) {
      return false;
    }
    if (filters.minPricePerPerson != null ||
        filters.maxPricePerPerson != null) {
      final min = merchant.pricePerPersonMin;
      final max = merchant.pricePerPersonMax;
      // Merchants with no price data at all are kept in (nothing to compare
      // against), rather than silently dropped by a price filter.
      if (min != null || max != null) {
        final merchantMin = min ?? max!;
        final merchantMax = max ?? min!;
        final filterMin = filters.minPricePerPerson ?? double.negativeInfinity;
        final filterMax = filters.maxPricePerPerson ?? double.infinity;
        final overlaps = merchantMin <= filterMax && merchantMax >= filterMin;
        if (!overlaps) return false;
      }
    }
    if (filters.dietTagIds.isNotEmpty) {
      final tagIds = merchantTagIds[merchant.id] ?? const <int>{};
      if (!filters.dietTagIds.any(tagIds.contains)) return false;
    }
    if (filters.hideVisited &&
        (visitCountsByMerchant[merchant.id] ?? 0) > 0) {
      return false;
    }
    if (filters.openNowOnly) {
      final hours = businessHoursByMerchant[merchant.id] ?? const [];
      if (!isOpenNow(hours, effectiveNow)) return false;
    }
    if (filters.rewardAvailableOnly) {
      final rules = loyaltyRulesByMerchant[merchant.id] ?? const [];
      final visits = visitCountsByMerchant[merchant.id] ?? 0;
      if (!hasAvailableReward(rules, visits)) return false;
    }
    return true;
  }).toList();

  switch (filters.sort) {
    case SortOption.relevance:
      break; // Keep the incoming (text-match) order as-is.
    case SortOption.distance:
      result.sort(
        (a, b) => distanceKmFromUser(a).compareTo(distanceKmFromUser(b)),
      );
    case SortOption.price:
      result.sort(
        (a, b) => _representativePrice(a).compareTo(_representativePrice(b)),
      );
    case SortOption.mostVisited:
      result.sort(
        (a, b) => (visitCountsByMerchant[b.id] ?? 0).compareTo(
          visitCountsByMerchant[a.id] ?? 0,
        ),
      );
  }
  return result;
}

/// Lowest known price-per-person for [merchant], or `double.infinity` if it
/// has no price data (sorts those merchants last, never first, under
/// [SortOption.price]).
double _representativePrice(Merchant merchant) =>
    merchant.pricePerPersonMin ?? merchant.pricePerPersonMax ?? double.infinity;

// ---------------------------------------------------------------------------
// Home AI search -> search screen handoff
// ---------------------------------------------------------------------------

/// Everything [SearchScreen] needs to jump straight into a result set
/// resolved by the home hero's AI search, passed via `go_router`'s route
/// `extra` (see `core/router/app_router.dart`) instead of URL query params —
/// unlike web's shareable `/buscar?type=...&hood=...` URL, this app has no
/// deep-linking requirement for AI search results yet, so a plain in-memory
/// object avoids a query-string (de)serialization layer for
/// [MerchantType]/[SearchFilters] under time pressure.
@immutable
class SearchScreenInitial {
  const SearchScreenInitial({
    required this.query,
    this.filters = const SearchFilters(),
    this.startInPlatos = false,
  });

  /// The free-text fragment to seed the results screen's own search field
  /// with — Gemini's `query` field on success (may be empty when the query
  /// was fully covered by structured filters), or the visitor's raw typed
  /// text when the backend call itself failed (degrade, mirrors
  /// `AiSearchResolver.tsx`'s catch branch).
  final String query;

  final SearchFilters filters;

  /// Whether to land on the "Platos" result mode instead of the default
  /// "Lugares" — mirrors `resolve-ai-search.ts`'s `mode` mapping
  /// (`result_mode === "platos"`).
  final bool startInPlatos;
}

/// Maps the backend's structured [SearchQueryFilters] onto this app's own
/// [SearchScreenInitial]/[SearchFilters] vocabulary — the Flutter analogue
/// of web's `resolve-ai-search.ts` `resolveAiSearchFilters`. [allTags]
/// resolves Gemini's tag *names* to this app's tag *ids*
/// (`SearchFilters.dietTagIds`); an unknown/out-of-vocabulary name is
/// silently dropped, same posture as `SearchQueryParser#sanitize_tags!` on
/// the backend.
SearchScreenInitial mapSearchQueryFiltersToInitial(
  SearchQueryFilters filters,
  List<Tag> allTags,
) {
  MerchantType? type;
  final rawType = filters.type;
  if (rawType != null) {
    try {
      type = MerchantTypeJson.fromJson(rawType);
    } catch (_) {
      // Shouldn't happen — the backend's schema enum only allows real
      // `merchant_type_enum` values — but a client-side parse must never
      // crash the whole AI search over an unexpected value.
      type = null;
    }
  }

  final tagIds = <int>{};
  if (filters.tags.isNotEmpty) {
    final idByName = {for (final tag in allTags) tag.name: tag.id};
    for (final name in filters.tags) {
      final id = idByName[name];
      if (id != null) tagIds.add(id);
    }
  }

  return SearchScreenInitial(
    // On success, an absent `query` means Gemini considered the request
    // fully covered by the structured fields above — NOT a signal to fall
    // back to the visitor's raw text (that fallback only belongs to a real
    // request failure, handled by the caller). Mirrors `AiSearchResolver
    // .tsx`'s `.then` branch, which passes `filters.q` (nullable) through
    // as-is rather than substituting the original query string.
    query: filters.query?.trim() ?? '',
    filters: SearchFilters(
      merchantType: type,
      openNowOnly: filters.open == true,
      // A single Gemini-estimated price-per-person reads as a budget
      // ceiling ("barato" -> a low number), not an exact point value this
      // app's `RangeSlider`-shaped filter could match precisely — so this
      // maps onto the upper bound only, leaving the lower bound open.
      maxPricePerPerson: filters.pricePerPerson,
      dietTagIds: tagIds,
      neighborhood: filters.neighborhood,
      rewardAvailableOnly: filters.reward == true,
    ),
    startInPlatos: filters.resultMode == 'platos',
  );
}
