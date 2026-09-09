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

  testWidgets('renders the header and the AI search hero', (tester) async {
    await _pumpHome(tester);

    // Stale-test correction: `HomeScreen`'s doc comment (and
    // `lib/features/home/widgets/home_header.dart`'s) documents Home as
    // now hero-only — no "Bienvenido a Fudo" welcome copy, no featured-
    // merchants grid below the hero (`FeaturedGrid` is kept unused
    // elsewhere on purpose, not rendered here) — mirroring
    // `web/app/(marketing)/page.tsx`'s own equivalent comment. The
    // wordmark used to be a literal "fudo" text label; it's a real logo
    // `Image.asset` now (`home_header.dart`: "This used to be a stylized
    // italic 'fudo' text wordmark here, which web never renders at all —
    // that mismatch was the bug"). This test used to assert all of the
    // above; it's been updated to assert what the header/hero actually
    // render today instead of removed functionality.
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Activar ubicación'), findsOneWidget);
    // `SearchHomeView`'s headline (`Text.rich`) — confirms the hero itself
    // actually rendered its real content, not just an empty shell.
    expect(find.textContaining('Encontrá dónde comer'), findsOneWidget);
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

  // A "tapping a featured card calls onOpenMerchant with its id" test used
  // to live here. Removed (not just skipped) — `HomeScreen` no longer
  // renders a featured-merchants grid at all (deliberate product decision:
  // Home is hero-only now, see the class doc comment above and
  // `openspec/changes/fudo-consumers-mvp/learnings.md` Decisión 19's "Otro
  // cambio de producto en la misma categoría" note on the Home
  // simplification, commit `cfcf166`), so there is no featured card left to
  // tap. `onOpenMerchant` itself is kept only for
  // `core/router/app_router.dart` call-site compatibility (see the field's
  // own doc comment on `HomeScreen`) and is never invoked from this screen
  // anymore — there is nothing left in `HomeScreen` for a test of this
  // callback to legitimately exercise.
}
