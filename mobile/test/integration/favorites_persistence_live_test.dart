// Real, end-to-end integration test for `RemoteDataSource.addFavorite`/
// `removeFavorite` against the actual Rails backend — NOT mocked. Confirms
// the mobile-side write actually persists (and un-persists) server-side, by
// checking with an independent, direct HTTP call (not just trusting
// `RemoteDataSource.getFavorites()`, which uses the same code path being
// tested) after each write.
//
// Same live-backend caveats as `remote_data_source_live_test.dart`: talks to
// `http://localhost:3000` for real, skips every test with a clear message if
// that backend isn't reachable, and is excluded from
// `flutter test --exclude-tags=integration`. Run it on its own:
//   flutter test test/integration/favorites_persistence_live_test.dart
//
// Demo credentials come from `backend/db/seeds.rb` (confirmed live, same
// ones the other integration files use): info@tomassalina.com / Demo1234,
// consumer "Tomas Salina".
//
// This test picks a merchant that is NOT currently favorited by the demo
// consumer (checked live at run time, rather than hardcoding a merchant id
// that could stop being true if the seeds change), favorites it, confirms
// the favorite exists server-side, then un-favorites it again — leaving the
// demo consumer's real favorites exactly as they were before the test ran.
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
/// approach as `remote_data_source_live_test.dart`.
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

/// Whether `http://localhost:3000/up` responds with `200` — same check as
/// the other integration files.
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

/// Raw `GET /favorites` (all pages), independent of `RemoteDataSource`, used
/// to verify persistence without relying on the same code path being
/// tested.
Future<List<Map<String, dynamic>>> _fetchFavoritesDirect(Dio dio) async {
  final results = <Map<String, dynamic>>[];
  var page = 1;
  while (true) {
    final response = await dio.get<Map<String, dynamic>>(
      '/favorites',
      queryParameters: {'page': page},
    );
    final body = response.data ?? const <String, dynamic>{};
    final data = (body['data'] as List<dynamic>?) ?? const <dynamic>[];
    results.addAll(data.cast<Map<String, dynamic>>());
    final meta = body['meta'] as Map<String, dynamic>?;
    final currentPage = meta?['current_page'] as int? ?? page;
    final totalPages = meta?['total_pages'] as int? ?? page;
    if (currentPage >= totalPages) break;
    page = currentPage + 1;
  }
  return results;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Same workaround as the other integration files: undo the test binding's
  // fake `HttpOverrides` so requests to localhost:3000 go out for real.
  HttpOverrides.global = null;

  late bool backendUp;

  setUpAll(() async {
    backendUp = await _isBackendUp();
  });

  test(
    'addFavorite persists server-side and removeFavorite un-persists it, '
    'leaving the demo consumer with no orphaned favorites',
    () async {
      if (!backendUp) {
        markTestSkipped(
          'backend real no disponible en localhost:3000, saltando test de '
          'persistencia de favoritos',
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

      // 2. Pick a merchant that is NOT currently favorited by the demo
      // consumer, checked live rather than hardcoded.
      final merchants = await remoteDataSource.getMerchants();
      final favoritesBefore = await _fetchFavoritesDirect(dio);
      final favoritedMerchantIdsBefore = favoritesBefore
          .map((f) => f['merchant_id'] as int)
          .toSet();
      final targetMerchant = merchants.firstWhere(
        (m) => !favoritedMerchantIdsBefore.contains(m.id),
        orElse: () => throw StateError(
          'Every seeded merchant is already favorited by the demo consumer '
          '— no free merchant id to test with. Un-favorite one manually to '
          'unblock this test.',
        ),
      );

      try {
        // 3. Favorite it through the mobile-side call under test.
        await remoteDataSource.addFavorite(targetMerchant.id);

        // 4. Confirm persistence with an independent direct call — not
        // `remoteDataSource.getFavorites()`, to avoid trusting the same
        // code path being tested.
        final favoritesAfterAdd = await _fetchFavoritesDirect(dio);
        final createdFavorite = favoritesAfterAdd.firstWhere(
          (f) => f['merchant_id'] == targetMerchant.id,
          orElse: () => throw StateError(
            'POST /favorites for merchant ${targetMerchant.id} did not '
            'show up in a follow-up GET /favorites — persistence failed.',
          ),
        );
        expect(createdFavorite['merchant_id'], targetMerchant.id);
        expect(createdFavorite['id'], isNotNull);
      } finally {
        // 5. Cleanup — always attempt this, even if the assertions above
        // failed, so a broken assertion doesn't leave a real orphaned
        // favorite behind on the seeded backend.
        await remoteDataSource.removeFavorite(targetMerchant.id);
      }

      // 6. Confirm the cleanup actually un-persisted it, independent of
      // the code path being tested.
      final favoritesAfterRemove = await _fetchFavoritesDirect(dio);
      expect(
        favoritesAfterRemove.any(
          (f) => f['merchant_id'] == targetMerchant.id,
        ),
        isFalse,
        reason:
            'DELETE /favorites/{id} for merchant ${targetMerchant.id} left '
            'an orphaned favorite behind on the real backend.',
      );
      // 7. And the full set is back to exactly what it was before this
      // test ran.
      final favoritedMerchantIdsAfter = favoritesAfterRemove
          .map((f) => f['merchant_id'] as int)
          .toSet();
      expect(favoritedMerchantIdsAfter, favoritedMerchantIdsBefore);
    },
  );
}
