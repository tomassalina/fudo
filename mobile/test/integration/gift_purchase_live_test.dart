// Real, end-to-end integration test for `RemoteDataSource.createGift`
// against the actual Rails backend — NOT mocked. Confirms the mobile-side
// `POST /api/v1/gifts` call actually persists server-side, by checking with
// an independent, direct HTTP call (not just trusting
// `RemoteDataSource.getGifts()`, which uses the same code path being
// tested) after the write.
//
// Same live-backend caveats as `remote_data_source_live_test.dart` and
// `favorites_persistence_live_test.dart`: talks to `http://localhost:3000`
// for real, skips every test with a clear message if that backend isn't
// reachable, and is excluded from `flutter test --exclude-tags=integration`.
// Run it on its own:
//   flutter test test/integration/gift_purchase_live_test.dart
//
// Demo credentials come from `backend/db/seeds.rb` (confirmed live, same
// ones the other integration files use): info@tomassalina.com / Demo1234,
// consumer "Tomas Salina".
//
// UNLIKE the favorites test, this is a deliberate, intentional, undone
// side-effect: there is no `DELETE /api/v1/gifts/{id}` route in the real API
// (confirmed against the live OpenAPI doc — gifts, unlike favorites, are not
// something a consumer can retract once bought), so the gift card this test
// buys stays in the demo consumer's real `pending` gift history forever.
// That's expected and acceptable for a demo account — this test does not
// attempt (and cannot attempt) any cleanup.
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
import 'package:mobile/data/models/gift.dart';
import 'package:mobile/data/remote/remote_data_source.dart';

const _demoEmail = 'info@tomassalina.com';
const _demoPassword = 'Demo1234';
const _healthCheckUrl = 'http://localhost:3000/up';

/// In-memory stand-in for the native secure storage platform channel — same
/// approach as the other integration files.
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

/// Raw `GET /gifts` (all pages), independent of `RemoteDataSource`, used to
/// verify persistence without relying on the same code path being tested.
Future<List<Map<String, dynamic>>> _fetchGiftsDirect(Dio dio) async {
  final results = <Map<String, dynamic>>[];
  var page = 1;
  while (true) {
    final response = await dio.get<Map<String, dynamic>>(
      '/gifts',
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
    'createGift persists a real, server-side pending gift owned by the '
    'authenticated consumer',
    () async {
      if (!backendUp) {
        markTestSkipped(
          'backend real no disponible en localhost:3000, saltando test de '
          'compra de gift card',
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
      final senderConsumerId = consumerSession.consumer!.id;

      // 2. Buy a Classic gift card through the mobile-side call under test.
      final recipientPhone = '+54 9 11 5555 0000';
      final created = await remoteDataSource.createGift(
        type: GiftType.classic,
        amount: 12000,
        recipientPhone: recipientPhone,
      );

      // 3. The immediate 201 response already reflects the confirmed
      // contract.
      expect(created.status, GiftStatus.pending);
      expect(created.senderConsumerId, senderConsumerId);
      expect(created.type, GiftType.classic);
      expect(created.recipientPhone, recipientPhone);

      // 4. Confirm persistence with an independent direct call — not
      // `remoteDataSource.getGifts()`, to avoid trusting the same code path
      // being tested.
      //
      // NOTE (discovered live): `GET /gifts`'s list serializer is thinner
      // than `POST /gifts`'s — it omits `recipient_phone`/`message`, only
      // returning `id`/`amount`/`expires_at`/`recipient_consumer_id`/
      // `sender_consumer_id`/`status`/`type`. So this only re-checks the
      // fields the list endpoint actually exposes; `recipientPhone` was
      // already confirmed above from the `POST /gifts` response itself.
      final giftsAfter = await _fetchGiftsDirect(dio);
      final persisted = giftsAfter.firstWhere(
        (g) => g['id'] == created.id,
        orElse: () => throw StateError(
          'POST /gifts (id ${created.id}) did not show up in a follow-up '
          'GET /gifts — persistence failed.',
        ),
      );
      expect(persisted['status'], 'pending');
      expect(persisted['sender_consumer_id'], senderConsumerId);
      expect(persisted['type'], 'classic');

      // 5. Regression check (found by review): GET /gifts omitting
      // recipient_phone entirely used to make Gift.fromJson throw a
      // null-cast error the instant this method was called for real —
      // fixed by defaulting recipientPhone to '' when absent (see that
      // model's doc comment). Exercise the actual RemoteDataSource.getGifts()
      // path (not the raw _fetchGiftsDirect above) to prove it no longer
      // crashes against the real list shape.
      final giftsViaDataSource = await remoteDataSource.getGifts();
      final ourGift = giftsViaDataSource.firstWhere(
        (g) => g.id == created.id,
        orElse: () => throw StateError(
          'getGifts() did not return the gift (id ${created.id}) that '
          '_fetchGiftsDirect just confirmed exists — something else broke.',
        ),
      );
      expect(ourGift.status, GiftStatus.pending);
      expect(ourGift.recipientPhone, ''); // not present on the list endpoint

      // 6. Deliberately NOT undone — see this file's header doc. There is
      // no `DELETE /api/v1/gifts/{id}` route in the real API, so gift id
      // ${created.id} stays a real `pending` row in the demo consumer's
      // gift history after this test runs.
    },
  );
}
