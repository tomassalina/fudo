// Widget tests for `MyPlacesScreen`'s `ConnectionMode.remote` login path —
// unlike `my_places_screen_test.dart` (fake/instant login, `local` mode,
// untouched by this file), this wires the login form to a REAL request
// against `AuthRepository`/the live Rails backend.
//
// `ConnectionMode.remote` is forced via `connectionModeProvider`'s
// `ProviderScope` override (`data/providers.dart`) instead of a
// `--dart-define=CONNECTION_MODE=remote` relaunch — the least invasive way
// to make the compile-time-resolved `connectionMode` constant overridable in
// a test, without touching `data/connection_mode.dart` itself or any
// existing test that relies on its current (dependency-free) shape.
//
// Tagged `integration` and deliberately excluded from
// `flutter test --exclude-tags=integration` — same reasoning as
// `test/integration/remote_data_source_live_test.dart`: this hits
// `http://localhost:3000` for real. Run it on its own:
//   flutter test test/features/my_places_screen_remote_login_test.dart
//
// Demo credentials come from `backend/db/seeds.rb` (confirmed live, same
// ones `remote_data_source_live_test.dart` uses): info@tomassalina.com /
// Demo1234, consumer "Tomas Salina".
@Tags(['integration'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart'
    hide Options;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/connection_mode.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/my_places/my_places_screen.dart';

const _demoEmail = 'info@tomassalina.com';
const _demoPassword = 'Demo1234';
const _healthCheckUrl = 'http://localhost:3000/up';

/// In-memory stand-in for the native secure storage platform channel — same
/// approach as `test/core/token_storage_test.dart` and
/// `test/integration/remote_data_source_live_test.dart`, needed because
/// `flutter_secure_storage` talks to a `MethodChannel` that doesn't exist
/// under `flutter test`'s Dart-only VM.
class _FakeFlutterSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.of(_values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

/// Whether `http://localhost:3000/up` (Rails' default health check) responds
/// with `200` — same check as `remote_data_source_live_test.dart`.
Future<bool> _isBackendUp() async {
  try {
    final response = await Dio().get<void>(
      _healthCheckUrl,
      options: Options(
        sendTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    );
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> _pumpMyPlacesScreenInRemoteMode(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectionModeProvider.overrideWithValue(ConnectionMode.remote),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const MyPlacesScreen()),
    ),
  );
  await tester.pump();
}

/// Fills the email/password fields, taps "Iniciar sesión", and lets the real
/// HTTP round trip against `localhost:3000` complete.
///
/// Unlike the fake/instant login in `my_places_screen_test.dart`, this is
/// genuine asynchronous I/O. `flutter_test` runs each test body inside a
/// `FakeAsync` zone, so any `Timer`/socket operation *started* outside
/// `tester.runAsync` (including the ones `dart:io` creates deep inside a
/// real DNS lookup/socket connect) becomes a fake timer that never actually
/// fires — the request would just hang forever no matter how long a plain
/// `Future.delayed` outside `runAsync` waits (confirmed by a throwaway run:
/// the login request never completed).
///
/// So every step that might start new real async work — the tap that
/// triggers `AuthRepository.login()`, and the follow-up `pump()` that (on
/// success) mounts `_LoggedInView` and immediately fires *its own* real
/// requests (`visitSummariesProvider`, `merchantsProvider`, …) — has to run
/// inside the same `runAsync` callback, interleaved with real-time waits so
/// each request's real timers actually get to fire before the next step.
Future<void> _submitRemoteLogin(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.pump();

  await tester.runAsync(() async {
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump(); // starts the real login POST
    await Future<void>.delayed(const Duration(seconds: 3));

    // On success this rebuild mounts `_LoggedInView`, which immediately
    // fires its own real GETs; on failure it's just the error message
    // appearing, with nothing new to wait for.
    await tester.pump();
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 3));
  });

  // Final pump in the normal zone to flush anything left pending — nothing
  // above should still be in flight by this point.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Same workaround as `remote_data_source_live_test.dart`: undo the test
  // binding's fake `HttpOverrides` so requests to localhost:3000 go out for
  // real instead of failing with a synthetic 400.
  HttpOverrides.global = null;
  // `AppTheme.dark` (used below to pump `MyPlacesScreen`) pulls its
  // TextTheme from `GoogleFonts`, which otherwise tries to fetch real font
  // files over the network the first time it runs — with the real
  // `HttpOverrides` reset above, that request actually goes out and leaves
  // a pending `Timer` behind when the test ends before it resolves
  // ("A Timer is still pending even after the widget tree was disposed.",
  // confirmed by a throwaway run without this line). Forcing the bundled
  // fallback font avoids that real request entirely.
  GoogleFonts.config.allowRuntimeFetching = false;

  late bool backendUp;

  setUpAll(() async {
    backendUp = await _isBackendUp();
  });

  setUp(() {
    // Fresh in-memory storage per test so a token saved by one test can't
    // leak into the next.
    FlutterSecureStoragePlatform.instance =
        _FakeFlutterSecureStoragePlatform();
  });

  testWidgets(
    'successful remote login shows the real logged-in consumer profile',
    (tester) async {
      if (!backendUp) {
        markTestSkipped(
          'backend real no disponible en localhost:3000, saltando test de '
          'login remoto',
        );
        return;
      }

      await _pumpMyPlacesScreenInRemoteMode(tester);
      expect(find.text('Iniciar sesión'), findsOneWidget);

      await _submitRemoteLogin(
        tester,
        email: _demoEmail,
        password: _demoPassword,
      );

      // Login form is gone, real consumer profile is shown instead.
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsNothing);
      expect(find.text('Tomas Salina'), findsOneWidget);
      expect(find.text(_demoEmail), findsOneWidget);
    },
  );

  testWidgets(
    'invalid credentials show the backend error message without crashing '
    'or losing the form',
    (tester) async {
      if (!backendUp) {
        markTestSkipped(
          'backend real no disponible en localhost:3000, saltando test de '
          'login remoto',
        );
        return;
      }

      await _pumpMyPlacesScreenInRemoteMode(tester);

      await _submitRemoteLogin(
        tester,
        email: _demoEmail,
        password: 'not-the-real-password',
      );

      // Still on the login form — no crash, no navigation to the profile.
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      // The backend's confirmed 401 body (see `AuthRepository`'s doc
      // comment): `{"error": "Invalid email or password"}`.
      expect(find.text('Invalid email or password'), findsOneWidget);
    },
  );
}
