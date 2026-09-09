// Real, end-to-end integration test against the actual Rails backend — NOT
// mocked. This is the test the project owner explicitly asked for: proof
// that `RemoteDataSource`/`AuthRepository` work against a live server, not
// just against fixtures or hand-written fakes.
//
// It talks to `http://localhost:3000` for real over HTTP. If that backend
// isn't reachable (e.g. in CI, or a machine where nobody ran
// `rails server`), every test in this file is marked `skip` with a clear
// message instead of failing red — this file is deliberately excluded from
// the "run everything" flow the rest of the suite uses (see
// `flutter test --exclude-tags=integration` / run this file on its own).
//
// Demo credentials come from `backend/db/seeds.rb` (confirmed live, not
// invented): info@tomassalina.com / Demo1234, consumer "Tomas Salina".
//
// IMPORTANT: `TestWidgetsFlutterBinding.ensureInitialized()` installs a fake
// `HttpOverrides.global` that makes every real `dart:io`/Dio request fail
// with a synthetic 400 (Flutter's test binding does this so ordinary widget
// tests can't accidentally hit the real network). This file deliberately
// wants real networking, so it resets `HttpOverrides.global = null` right
// after initializing the binding — confirmed via a throwaway probe test that
// this exact override was the cause of an otherwise-unexplained 400 from
// `GET /up` that plain `curl` never reproduced.
@Tags(['integration'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart'
    hide Options;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/token_storage.dart';
import 'package:mobile/core/config/dio_client.dart';
import 'package:mobile/data/auth/auth_repository.dart';
import 'package:mobile/data/auth/current_consumer_session.dart';
import 'package:mobile/data/remote/remote_data_source.dart';

const _demoEmail = 'info@tomassalina.com';
const _demoPassword = 'Demo1234';
const _healthCheckUrl = 'http://localhost:3000/up';

/// In-memory stand-in for the native secure storage platform channel — same
/// approach as `test/core/token_storage_test.dart`, needed because
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
/// with `200`.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // See the file-level doc comment above — undoes the test binding's fake
  // HttpOverrides so real requests to localhost:3000 actually go out.
  HttpOverrides.global = null;

  late bool backendUp;

  setUpAll(() async {
    backendUp = await _isBackendUp();
  });

  group('RemoteDataSource (live backend)', () {
    test(
      'login + getMerchants + getFavorites + getCurrentConsumer work against '
      'the real backend',
      () async {
        if (!backendUp) {
          markTestSkipped(
            'backend real no disponible en localhost:3000, saltando tests '
            'de integración',
          );
          return;
        }

        FlutterSecureStoragePlatform.instance =
            _FakeFlutterSecureStoragePlatform();
        final tokenStorage = const TokenStorage();
        final consumerSession = CurrentConsumerSession();
        final dio = DioClient.create(tokenStorage: tokenStorage);

        final authRepository = AuthRepository(
          dio,
          tokenStorage: tokenStorage,
          consumerSession: consumerSession,
        );
        final remoteDataSource = RemoteDataSource(
          dio,
          consumerSession: consumerSession,
        );

        // 1. Login for real.
        await authRepository.login(email: _demoEmail, password: _demoPassword);
        final savedToken = await tokenStorage.readToken();
        expect(savedToken, isNotNull);
        expect(savedToken, isNotEmpty);

        // 2. All 30 real seeded merchants come back, across both pages.
        final merchants = await remoteDataSource.getMerchants();
        expect(merchants, isNotEmpty);
        expect(merchants.length, 30);

        // 3. The demo consumer's real favorites come back, authenticated.
        final favorites = await remoteDataSource.getFavorites();
        expect(favorites, isNotEmpty);

        // 4. getCurrentConsumer() reads the session snapshot set by login().
        final consumer = await remoteDataSource.getCurrentConsumer();
        expect(consumer.firstName, 'Tomas');
        expect(consumer.lastName, 'Salina');
        expect(consumer.email, _demoEmail);
        expect(consumer.hasDniOnFile, isTrue);
      },
    );

    test(
      'getCurrentConsumer throws StateError before any login this session',
      () async {
        if (!backendUp) {
          markTestSkipped(
            'backend real no disponible en localhost:3000, saltando tests '
            'de integración',
          );
          return;
        }

        final dio = DioClient.create(tokenStorage: const TokenStorage());
        final remoteDataSource = RemoteDataSource(
          dio,
          consumerSession: CurrentConsumerSession(),
        );

        expect(
          () => remoteDataSource.getCurrentConsumer(),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
