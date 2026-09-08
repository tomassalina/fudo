import 'package:latlong2/latlong.dart';

/// App-wide constants shared across features.
class AppConstants {
  AppConstants._();

  /// Default map center: Palermo, Buenos Aires.
  static const LatLng defaultMapCenter = LatLng(-34.5875, -58.4205);

  static const double defaultMapZoom = 15;

  /// CartoDB Dark Matter tile layer (matches the dark app theme).
  /// No `{s}` subdomain placeholder needed — CARTO serves this endpoint
  /// from a single anycast host.
  static const String cartoDarkMatterTileUrl =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
}
