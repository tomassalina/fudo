import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Real device geolocation (`docs/flutter-vs-nextjs-gap-report.md`, "1.
/// Inicio/Home" — before this file, `distanceKmFromUser()` compared every
/// merchant against a hardcoded coordinate, so every distance shown in the
/// app was fictional).
///
/// Backs the home header's "Activar ubicación" pill
/// (`features/home/widgets/`) and `distanceKmFromUser()`
/// (`features/search/widgets/search_utils.dart`) — analogous to
/// `web/lib/location/use-location.ts` + `web/components/layout/
/// LocationButton.tsx`.
///
/// Wraps the `geolocator` plugin behind a small surface so callers (and
/// tests) never touch the plugin/platform channel directly. Every failure
/// mode — location services disabled, permission denied (once or
/// permanently), or any other plugin/platform error — resolves
/// [getCurrentPosition] to `null` instead of throwing, mirroring
/// `use-location.ts`'s "denied/unsupported/error all resolve into status
/// instead of throwing" contract: callers never need a try/catch.
class LocationService {
  const LocationService();

  /// Requests location permission if needed, then returns the device's
  /// current position — or `null` if location services are off, permission
  /// was denied (once or permanently), or the platform call otherwise
  /// failed.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
    } on Exception {
      // Any plugin/platform failure (timeout, unsupported platform, etc.)
      // degrades to "no real location available" rather than crashing the
      // caller — same contract as a denied permission.
      return null;
    }
  }
}

/// Reactive holder of the user's last known real device location.
///
/// A [ValueNotifier] rather than a Riverpod provider, on purpose: like
/// `web/lib/location/use-location.ts`'s module-level store, there is
/// exactly one producer (the device's location API, via [requestLocation])
/// and several independent readers that don't need a provider tree just to
/// read the latest coordinate — most notably `distanceKmFromUser()`
/// (`features/search/widgets/search_utils.dart`), a plain top-level
/// function with no `WidgetRef` to read a provider from. Widgets that need
/// to rebuild when it changes (the home header's pill, the featured grid)
/// wrap it in a `ValueListenableBuilder`.
///
/// `null` means "no real location to show" — covers "never requested yet",
/// "permission denied", and "platform call failed" alike, same as
/// `use-location.ts`'s `idle`/`denied`/`unsupported` all rendering the same
/// "Activar ubicación" look.
class UserLocationController extends ValueNotifier<LatLng?> {
  UserLocationController({this._service = const LocationService()})
    : super(null);

  final LocationService _service;

  /// Requests the real device location and, on success, updates [value].
  /// On any failure [value] is left untouched (see class doc).
  Future<void> requestLocation() async {
    final position = await _service.getCurrentPosition();
    if (position == null) return;
    value = LatLng(position.latitude, position.longitude);
  }

  /// Clears the previously activated location, going back to "Activar
  /// ubicación" — mirrors `use-location.ts`'s `clearLocation()`. This does
  /// not (and cannot, from Dart) revoke the OS-level permission grant; it
  /// just stops the app from using the last known position.
  void clearLocation() {
    value = null;
  }
}

/// App-wide [UserLocationController] instance.
///
/// Deliberately a mutable top-level variable, not `final`/`const`: widget
/// tests reassign it to a fresh controller wired to a fake [LocationService]
/// (see `test/core/location_service_test.dart` and
/// `test/features/home_screen_test.dart`) so they never touch the real
/// `geolocator` platform channel, then restore the original in `tearDown`.
UserLocationController userLocationController = UserLocationController();
