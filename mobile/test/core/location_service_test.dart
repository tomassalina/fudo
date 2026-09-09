// Tests for `LocationService`/`UserLocationController`
// (core/location/location_service.dart).
//
// `geolocator` talks to native platform code over a `MethodChannel`, which
// doesn't exist under `flutter test`'s Dart-only VM. Its plugin-platform-
// interface design makes a fake easy to write — same pattern
// `test/core/token_storage_test.dart` uses for `flutter_secure_storage`:
// `Geolocator`'s static methods only ever delegate to
// `GeolocatorPlatform.instance`, so swapping that static instance for an
// in-memory fake exercises `LocationService`'s real permission/service-
// enabled/position logic without touching a platform channel at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/location/location_service.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission permissionAfterRequest = LocationPermission.whileInUse;
  Position? position;
  Object? getCurrentPositionError;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (getCurrentPositionError != null) throw getCurrentPositionError!;
    return position!;
  }
}

Position _positionAt(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _FakeGeolocatorPlatform fakePlatform;
  late LocationService service;

  setUp(() {
    fakePlatform = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakePlatform;
    service = const LocationService();
  });

  group('LocationService.getCurrentPosition', () {
    test('returns the position when permission is already granted', () async {
      fakePlatform
        ..permission = LocationPermission.whileInUse
        ..position = _positionAt(-34.6, -58.4);

      final result = await service.getCurrentPosition();

      expect(result?.latitude, -34.6);
      expect(result?.longitude, -58.4);
    });

    test('requests permission when initially denied, then succeeds', () async {
      fakePlatform
        ..permission = LocationPermission.denied
        ..permissionAfterRequest = LocationPermission.always
        ..position = _positionAt(1, 2);

      final result = await service.getCurrentPosition();

      expect(result, isNotNull);
      expect(fakePlatform.permission, LocationPermission.always);
    });

    test('returns null when location services are disabled', () async {
      fakePlatform.serviceEnabled = false;

      final result = await service.getCurrentPosition();

      expect(result, isNull);
    });

    test('returns null when permission is denied after requesting', () async {
      fakePlatform
        ..permission = LocationPermission.denied
        ..permissionAfterRequest = LocationPermission.denied;

      final result = await service.getCurrentPosition();

      expect(result, isNull);
    });

    test('returns null when permission is denied forever', () async {
      fakePlatform.permission = LocationPermission.deniedForever;

      final result = await service.getCurrentPosition();

      expect(result, isNull);
    });

    test('returns null instead of throwing when the platform call fails', () async {
      fakePlatform
        ..permission = LocationPermission.whileInUse
        ..getCurrentPositionError = Exception('boom');

      final result = await service.getCurrentPosition();

      expect(result, isNull);
    });
  });

  group('UserLocationController', () {
    test('requestLocation sets value on success', () async {
      fakePlatform
        ..permission = LocationPermission.whileInUse
        ..position = _positionAt(10, 20);
      final controller = UserLocationController(service: service);

      await controller.requestLocation();

      expect(controller.value, const LatLng(10, 20));
    });

    test('requestLocation leaves value untouched on failure', () async {
      fakePlatform.serviceEnabled = false;
      final controller = UserLocationController(service: service);

      await controller.requestLocation();

      expect(controller.value, isNull);
    });

    test('clearLocation resets value to null', () async {
      fakePlatform
        ..permission = LocationPermission.whileInUse
        ..position = _positionAt(10, 20);
      final controller = UserLocationController(service: service);
      await controller.requestLocation();
      expect(controller.value, isNotNull);

      controller.clearLocation();

      expect(controller.value, isNull);
    });
  });
}
