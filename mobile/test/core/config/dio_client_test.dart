// Tests for `DioClient` (core/config/dio_client.dart)'s `401` handling: the
// interceptor clears the stored token and invokes the `onUnauthorized` hook
// `data/providers.dart`'s `dioProvider` wires to react at the app-state
// level (see `test/core/router/app_router_session_test.dart` for that
// end-to-end wiring). No real network is involved — a fake
// [HttpClientAdapter] stands in for the wire, same spirit as
// `test/core/token_storage_test.dart`'s fake secure-storage platform: swap
// the one seam Dio actually talks through instead of hitting a live server.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/token_storage.dart';
import 'package:mobile/core/config/dio_client.dart';

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

/// Always responds with a fixed [statusCode]/[body] regardless of the
/// request — the tests below only care about how `DioClient` reacts to the
/// status code, not about exercising a real endpoint's shape.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
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
  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeFlutterSecureStoragePlatform();
  });

  test('a 401 response clears the stored token', () async {
    const tokenStorage = TokenStorage();
    await tokenStorage.saveToken('stale-token');

    final dio = DioClient.create(tokenStorage: tokenStorage)
      ..httpClientAdapter = _FakeHttpClientAdapter(401);

    await expectLater(
      dio.get<void>('/anything'),
      throwsA(isA<DioException>()),
    );

    expect(await tokenStorage.readToken(), isNull);
  });

  test('a 401 response invokes onUnauthorized exactly once', () async {
    var calls = 0;
    final dio = DioClient.create(onUnauthorized: () => calls++)
      ..httpClientAdapter = _FakeHttpClientAdapter(401);

    await expectLater(
      dio.get<void>('/anything'),
      throwsA(isA<DioException>()),
    );

    expect(calls, 1);
  });

  test(
    'a non-401 error does not invoke onUnauthorized or clear the token',
    () async {
      const tokenStorage = TokenStorage();
      await tokenStorage.saveToken('still-valid');
      var calls = 0;

      final dio = DioClient.create(
        tokenStorage: tokenStorage,
        onUnauthorized: () => calls++,
      )..httpClientAdapter = _FakeHttpClientAdapter(500);

      await expectLater(
        dio.get<void>('/anything'),
        throwsA(isA<DioException>()),
      );

      expect(calls, 0);
      expect(await tokenStorage.readToken(), 'still-valid');
    },
  );

  test('a successful (2xx) response never touches the token', () async {
    const tokenStorage = TokenStorage();
    await tokenStorage.saveToken('still-valid');
    var calls = 0;

    final dio = DioClient.create(
      tokenStorage: tokenStorage,
      onUnauthorized: () => calls++,
    )..httpClientAdapter = _FakeHttpClientAdapter(200);

    await dio.get<void>('/anything');

    expect(calls, 0);
    expect(await tokenStorage.readToken(), 'still-valid');
  });
}
