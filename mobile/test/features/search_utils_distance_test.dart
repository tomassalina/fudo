// Tests for `distanceKmFromUser()` (features/search/widgets/search_utils.dart)
// against real vs. simulated user location
// (`core/location/location_service.dart`'s `userLocationController`).
//
// Scoped to just this function on purpose — `applySearchFilters()` in the
// same file is owned by a different task (see `docs/
// flutter-vs-nextjs-gap-report.md`, Tarea 2) and has its own test coverage.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/constants/app_constants.dart';
import 'package:mobile/core/location/location_service.dart';
import 'package:mobile/data/models/merchant.dart';
import 'package:mobile/features/search/widgets/search_utils.dart';

Merchant _merchantAt(double lat, double lng) => Merchant(
  id: 1,
  name: 'Test merchant',
  type: MerchantType.restaurant,
  address: '',
  country: '',
  state: '',
  city: 'Buenos Aires',
  latitude: lat,
  longitude: lng,
);

void main() {
  final originalController = userLocationController;

  setUp(() {
    userLocationController = UserLocationController();
  });

  tearDown(() {
    userLocationController = originalController;
  });

  test(
    'falls back to AppConstants.defaultMapCenter when no real location was '
    'activated',
    () {
      final merchant = _merchantAt(
        AppConstants.defaultMapCenter.latitude,
        AppConstants.defaultMapCenter.longitude,
      );

      expect(distanceKmFromUser(merchant), closeTo(0, 0.0001));
    },
  );

  test('uses the real device location once it has been activated', () {
    userLocationController.value = const LatLng(-34.6037, -58.3816);
    final merchant = _merchantAt(-34.6037, -58.3816);

    expect(distanceKmFromUser(merchant), closeTo(0, 0.0001));
  });

  test(
    'no longer measures against the simulated center once a real location '
    'is set',
    () {
      final merchant = _merchantAt(
        AppConstants.defaultMapCenter.latitude,
        AppConstants.defaultMapCenter.longitude,
      );
      // Far from the simulated center — Mar del Plata.
      userLocationController.value = const LatLng(-38.0055, -57.5426);

      expect(distanceKmFromUser(merchant), greaterThan(300));
    },
  );

  test('clearLocation() reverts to the simulated fallback', () {
    userLocationController.value = const LatLng(-38.0055, -57.5426);
    userLocationController.clearLocation();
    final merchant = _merchantAt(
      AppConstants.defaultMapCenter.latitude,
      AppConstants.defaultMapCenter.longitude,
    );

    expect(distanceKmFromUser(merchant), closeTo(0, 0.0001));
  });
}
