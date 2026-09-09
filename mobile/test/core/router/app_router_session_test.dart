// Widget/router-level tests for the two auth-state-reactive behaviors added
// to `core/router/app_router.dart`'s `ShellRoute` gate:
//
// 1. It watches `sessionRestoreProvider` (data/providers.dart) BEFORE
//    `isLoggedInProvider`, showing a loading splash while a cold-start
//    session restore is in flight instead of flashing the login screen and
//    then flipping to logged-in — see that provider's doc. The restore
//    LOGIC itself (storage, the validation request, the decision branches)
//    is covered deterministically by `test/data/session_restore_test.dart`;
//    this file controls exactly when it resolves via a `Completer`, so the
//    splash-vs-content assertions below don't race real async I/O against
//    Flutter's frame pump timing.
// 2. `dioProvider`'s `onUnauthorized` hook (a real `401` on ANY request)
//    flips `isLoggedInProvider` to `false`, which this `ShellRoute` gate is
//    already watching — this file proves that reaction is genuinely
//    end-to-end: a real 401 response through the real `dioProvider`
//    instance results in the router actually rendering the login screen,
//    not just the provider flipping in isolation.
//
// No real network involved — a fake `HttpClientAdapter` stands in for the
// wire, same approach as `test/core/config/dio_client_test.dart` and
// `test/data/session_restore_test.dart`.
//
// The 401 test below awaits a real `dio` request from OUTSIDE any widget
// event handler (a direct call, not a button tap), so — same gotcha
// `test/features/my_places_screen_remote_login_test.dart` documents at
// length — it has to run inside `tester.runAsync()`: `flutter_test` runs
// each test body in a zone where `Timer`-driven continuations (which
// `Dio`'s request pipeline uses internally, even against our fake adapter,
// to enforce `connectTimeout`/`receiveTimeout`) never fire unless something
// is actively pumping frames/real time forward. Confirmed live: the same
// `await` outside `runAsync` hangs until the test's own timeout; wrapped in
// `runAsync`, it resolves immediately.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:mobile/data/connection_mode.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/main.dart';

/// In-memory stand-in for the native secure storage platform channel — same
/// fake as `test/core/token_storage_test.dart`. Only the `ConnectionMode
/// .remote` test below actually exercises it (via `dioProvider`'s
/// `onRequest` interceptor, which reads the token on every request) — set
/// up unconditionally anyway so nothing here depends on test order.
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

/// Always responds with a fixed status/body to any request.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.statusCode, {this.body = '{"data": []}'});

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // `AppTheme.dark` (pulled in by `FudoConsumersApp`) sources its TextTheme
  // from `GoogleFonts`, which otherwise tries to fetch real font files over
  // the network the first time it runs — same workaround as
  // `test/features/my_places_screen_remote_login_test.dart`, here just to
  // keep test output free of its (non-fatal, but noisy) fetch-failure
  // stack traces, since this file's fake adapter never lets a real request
  // through anyway.
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
  });

  testWidgets(
    'shows a loading splash while sessionRestoreProvider resolves — not '
    'the login screen — then shows the login screen once it resolves to '
    'logged-out',
    (tester) async {
      final completer = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          // Fully controlled: this test decides exactly when "restore"
          // finishes, instead of racing the real async chain.
          sessionRestoreProvider.overrideWith((ref) => completer.future),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FudoConsumersApp(),
        ),
      );
      await tester.pump();

      // Still resolving: neither the login screen nor the shell shows.
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsNothing);
      expect(find.byIcon(Symbols.home), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      // Resolved with isLoggedInProvider at its untouched default (false)
      // — lands on the login screen, not the shell.
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);
      expect(find.byIcon(Symbols.home), findsNothing);
    },
  );

  testWidgets(
    'once sessionRestoreProvider resolves with isLoggedInProvider true, the '
    'shell shows instead of the login screen',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionRestoreProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      container.read(isLoggedInProvider.notifier).logIn();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FudoConsumersApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Symbols.home), findsOneWidget);
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsNothing);
    },
  );

  testWidgets(
    'a real 401 through the shared dioProvider instance flips '
    'isLoggedInProvider and the router redirects to the login screen — '
    'end-to-end, not just the provider in isolation',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.remote),
          // Skip restore entirely — this test is about the 401 path, not
          // cold-start restore (covered elsewhere).
          sessionRestoreProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)
        ..httpClientAdapter = _FakeHttpClientAdapter(200);
      container.read(isLoggedInProvider.notifier).logIn();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FudoConsumersApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on the real shell, logged in.
      expect(find.byIcon(Symbols.home), findsOneWidget);
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsNothing);

      // Any subsequent authenticated request now comes back 401 — the
      // real-world trigger is an expired/revoked token on a live screen's
      // request; calling the data source directly here is the same
      // request path (`RemoteDataSource` -> the shared `dio` instance)
      // without depending on which screen/provider happens to fire first.
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        401,
        body: '{"error": "Invalid or expired token"}',
      );
      // `runAsync` is required here, not optional: this awaits a real `dio`
      // request from outside any widget event handler, and `flutter_test`
      // only lets `Timer`-driven continuations (which `Dio` uses internally
      // for `connectTimeout`/`receiveTimeout`, even against our fake
      // adapter) fire while something is actively pumping — see this
      // file's top comment for the confirmed-live gotcha and
      // `test/features/my_places_screen_remote_login_test.dart` for the
      // established precedent.
      await tester.runAsync(() async {
        await expectLater(
          container.read(dataSourceProvider).getFavorites(),
          throwsA(isA<DioException>()),
        );
      });
      await tester.pump();

      expect(container.read(isLoggedInProvider), isFalse);
      expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);
      expect(find.byIcon(Symbols.home), findsNothing);
    },
  );
}
