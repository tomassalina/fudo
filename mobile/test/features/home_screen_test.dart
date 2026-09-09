// Widget tests for `HomeScreen` (features/home/home_screen.dart) — the
// "Inicio" tab added by `docs/flutter-vs-nextjs-gap-report.md` Tarea 1.
//
// Same asset pre-warming workaround as `search_results_list_test.dart` /
// `filters_sheet_test.dart`. Location permission/position calls are faked
// the same way `test/core/location_service_test.dart` does, so this never
// touches the real `geolocator` platform channel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:mobile/core/location/location_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/home/home_screen.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  final Position position = Position(
    latitude: -34.6037,
    longitude: -58.3816,
    timestamp: DateTime(2026),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => position;
}

late LocalDataSource _warmDataSource;
late UserLocationController _originalController;

Future<void> _pumpHome(
  WidgetTester tester, {
  ValueChanged<int>? onOpenMerchant,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(onOpenMerchant: onOpenMerchant ?? (_) {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dataSource = LocalDataSource();
    await dataSource.getMerchants();
    _warmDataSource = dataSource;
  });

  setUp(() {
    _originalController = userLocationController;
    userLocationController = UserLocationController(
      service: const LocationService(),
    );
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
  });

  tearDown(() {
    userLocationController = _originalController;
  });

  testWidgets('renders the header, welcome copy and featured grid', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.text('fudo'), findsOneWidget);
    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(find.text('Bienvenido a Fudo'), findsOneWidget);
    expect(find.text('Lugares destacados'), findsOneWidget);
    // Fixture's first merchant (id 1) — confirms real merchant data reached
    // the featured grid, not just an empty/loading state.
    expect(find.text('Don Chile Cantina'), findsOneWidget);
  });

  testWidgets('tapping "Activar ubicación" activates the real location', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(userLocationController.value, isNull);

    await tester.tap(find.text('Activar ubicación'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Ubicación activada'), findsOneWidget);
    expect(userLocationController.value, isNotNull);
  });

  testWidgets('tapping "Ubicación activada" clears the activated location', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tap(find.text('Activar ubicación'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ubicación activada'), findsOneWidget);

    await tester.tap(find.text('Ubicación activada'));
    await tester.pump();

    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(userLocationController.value, isNull);
  });

  testWidgets('tapping a featured card calls onOpenMerchant with its id', (
    tester,
  ) async {
    int? openedId;
    await _pumpHome(tester, onOpenMerchant: (id) => openedId = id);

    await tester.tap(find.text('Don Chile Cantina'));
    await tester.pump();

    expect(openedId, 1);
  });
}
