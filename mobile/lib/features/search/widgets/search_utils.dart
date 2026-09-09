import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formatting/currency_format.dart';
import '../../../data/models/merchant.dart';

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

/// Distance in kilometers from the simulated "user location"
/// ([AppConstants.defaultMapCenter]) to [merchant].
double distanceKmFromUser(Merchant merchant) => _distanceCalculator.as(
  LengthUnit.Kilometer,
  AppConstants.defaultMapCenter,
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
/// Two fields are intentionally modeled but NOT applied by
/// [applySearchFilters]: [openNowOnly] and [rewardAvailableOnly]. Both would
/// require cross-referencing every merchant in the list against per-merchant
/// data (`business_hours`/`loyalty_rules` + `visit_summaries`) that the
/// [DataSource] interface only exposes scoped to a single merchant id today
/// — doing that for the whole result set from this sheet would mean N extra
/// fetches per filter change. They're kept on the model (and rendered as
/// real toggles in the sheet) so the UI/UX matches the design brief and the
/// count badge reflects the user's full intent, but callers that later add a
/// bulk data source method for either can wire them into
/// [applySearchFilters] without changing this class's shape.
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

/// Applies [filters] on top of a list already narrowed by [filterMerchants]'
/// free-text query — this is an extension of that filter, not a parallel
/// system.
///
/// [merchantTagIds] is `merchantTagIdsProvider`'s value (merchant id → its
/// tag ids), used for the "dieta" filter. [visitCountsByMerchant] is derived
/// from `visitSummariesProvider(null)` (merchant id → visit count), used for
/// "Ocultar visitados" and the "Más visitados" sort. Both default to empty
/// maps so this stays callable before those providers resolve — filters that
/// need them simply have no effect yet in that window.
///
/// [openNowOnly] and [rewardAvailableOnly] are read from [filters] but never
/// checked here — see the class doc on [SearchFilters] for why.
List<Merchant> applySearchFilters(
  List<Merchant> merchants,
  SearchFilters filters, {
  Map<int, Set<int>> merchantTagIds = const {},
  Map<int, int> visitCountsByMerchant = const {},
}) {
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
