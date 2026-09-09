// Tests for `sessionRestoreProvider` (data/providers.dart) — cold-start
// session restore, the fix for `current_consumer_session.dart`/
// `IsLoggedInNotifier` silently resetting to logged-out on every app
// launch despite a durably persisted token.
//
// These exercise the restore LOGIC directly through a `ProviderContainer`
// (awaiting `sessionRestoreProvider.future`) rather than pumping widgets —
// deterministic, no Flutter frame-timing involved, same spirit as
// `test/data/providers_test.dart`. The router-level reaction (the loading
// splash, and the eventual `MyPlacesScreen`/shell branch) is covered
// separately by `test/core/router/app_router_session_test.dart`, using
// controlled `Completer`s instead of racing this real async chain against
// widget pumping.
//
// No real network involved — a fake `HttpClientAdapter` stands in for the
// wire, same approach as `test/core/config/dio_client_test.dart`. Secure
// storage is faked the same way as `test/core/token_storage_test.dart`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/auth/token_storage.dart';
import 'package:mobile/data/connection_mode.dart';
import 'package:mobile/data/models/consumer.dart';
import 'package:mobile/data/providers.dart';

/// In-memory stand-in for the native secure storage platform channel — same
/// fake as `test/core/token_storage_test.dart`.
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

/// Throws on every call — used to prove [ConnectionMode.local] never
/// touches secure storage at all during restore, rather than merely
/// happening to work against a fake.
class _ThrowingSecureStoragePlatform extends FlutterSecureStoragePlatform {
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw StateError('secure storage should not be touched');

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('secure storage should not be touched');

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('secure storage should not be touched');

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('secure storage should not be touched');

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => throw StateError('secure storage should not be touched');

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      throw StateError('secure storage should not be touched');
}

/// Always responds with a fixed status/body to any request — the
/// `getConsumerSettings()` validation call is the only request
/// `sessionRestoreProvider` ever makes.
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

const _demoConsumer = Consumer(
  id: 'c1',
  firstName: 'Tomas',
  lastName: 'Salina',
  email: 'tomas@example.com',
  hasDniOnFile: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sessionRestoreProvider starts AsyncLoading the instant it is first read '
    '(the loading-state contract the router gate depends on)',
    () {
      FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.local),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(sessionRestoreProvider);
      expect(value.isLoading, isTrue);
      expect(value.hasValue, isFalse);
      expect(value.hasError, isFalse);
    },
  );

  test(
    'ConnectionMode.local resolves immediately without touching secure '
    'storage, and leaves isLoggedInProvider false',
    () async {
      FlutterSecureStoragePlatform.instance = _ThrowingSecureStoragePlatform();
      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.local),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionRestoreProvider.future);

      expect(container.read(isLoggedInProvider), isFalse);
    },
  );

  test(
    'ConnectionMode.remote with no persisted token resolves without logging '
    'in',
    () async {
      FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.remote),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionRestoreProvider.future);

      expect(container.read(isLoggedInProvider), isFalse);
    },
  );

  test(
    'a valid persisted token+consumer, confirmed by the backend, restores '
    'the full session (isLoggedInProvider + the consumer snapshot)',
    () async {
      FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
      const tokenStorage = TokenStorage();
      await tokenStorage.saveToken('valid-token');
      await tokenStorage.saveConsumerJson(jsonEncode(_demoConsumer.toJson()));

      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.remote),
        ],
      );
      addTearDown(container.dispose);
      container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter(
        200,
      );

      await container.read(sessionRestoreProvider.future);

      expect(container.read(isLoggedInProvider), isTrue);
      // `Consumer` has no `==` override (identity equality only), and the
      // restored instance was rebuilt from JSON — a different object than
      // `_demoConsumer` even with identical fields — so this compares the
      // fields it actually cares about instead of object identity.
      final restored = container.read(currentConsumerSessionProvider).consumer;
      expect(restored?.id, _demoConsumer.id);
      expect(restored?.email, _demoConsumer.email);
      expect(restored?.firstName, _demoConsumer.firstName);
      expect(restored?.lastName, _demoConsumer.lastName);
    },
  );

  test(
    'a persisted token the backend rejects with 401 clears the whole '
    'session and stays logged out',
    () async {
      FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
      const tokenStorage = TokenStorage();
      await tokenStorage.saveToken('expired-token');
      await tokenStorage.saveConsumerJson(jsonEncode(_demoConsumer.toJson()));

      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.remote),
        ],
      );
      addTearDown(container.dispose);
      container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter(
        401,
        body: '{"error": "Invalid or expired token"}',
      );

      await container.read(sessionRestoreProvider.future);

      expect(container.read(isLoggedInProvider), isFalse);
      expect(await tokenStorage.readToken(), isNull);
      expect(await tokenStorage.readConsumerJson(), isNull);
      expect(container.read(currentConsumerSessionProvider).consumer, isNull);
    },
  );

  test(
    'a persisted token the validation request cannot reach (non-401 '
    'failure, e.g. offline/5xx) trusts the cached session instead of '
    'forcing a logout',
    () async {
      FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
      const tokenStorage = TokenStorage();
      await tokenStorage.saveToken('valid-token');
      await tokenStorage.saveConsumerJson(jsonEncode(_demoConsumer.toJson()));

      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.remote),
        ],
      );
      addTearDown(container.dispose);
      container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter(
        500,
        body: '{"error": "Internal Server Error"}',
      );

      await container.read(sessionRestoreProvider.future);

      expect(container.read(isLoggedInProvider), isTrue);
      // The token/consumer snapshot are left untouched — nothing here
      // confirmed they're actually invalid.
      expect(await tokenStorage.readToken(), 'valid-token');
    },
  );

  test(
    'a token with no matching consumer snapshot (corrupted/partial local '
    'data) is treated as nothing to restore, not a crash',
    () async {
      FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
      const tokenStorage = TokenStorage();
      await tokenStorage.saveToken('orphaned-token');
      // No matching saveConsumerJson call.

      final container = ProviderContainer(
        overrides: [
          connectionModeProvider.overrideWithValue(ConnectionMode.remote),
        ],
      );
      addTearDown(container.dispose);
      container.read(dioProvider).httpClientAdapter = _FakeHttpClientAdapter(
        200,
      );

      await container.read(sessionRestoreProvider.future);

      expect(container.read(isLoggedInProvider), isFalse);
      expect(await tokenStorage.readToken(), isNull);
    },
  );
}
