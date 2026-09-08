import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
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
    return '${_formatMoney(min)} – ${_formatMoney(max)}';
  }
  return _formatMoney(min ?? max!);
}

String _formatMoney(double value) {
  final intValue = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < intValue.length; i++) {
    if (i != 0 && (intValue.length - i) % 3 == 0) buffer.write('.');
    buffer.write(intValue[i]);
  }
  return '\$$buffer';
}
