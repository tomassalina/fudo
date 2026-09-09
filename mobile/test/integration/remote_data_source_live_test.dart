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
import 'package:mobile/data/models/business_hour.dart' show DayOfWeek;
import 'package:mobile/data/remote/remote_data_source.dart';
import 'package:mobile/features/search/widgets/search_utils.dart'
    show SearchFilters, applySearchFilters, hasAvailableReward, isOpenNow;

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

/// Independent reference implementation of "is this merchant open right
/// now", worked directly from the RAW `GET /business_hours` JSON (the exact
/// shape `curl` sees) rather than through `BusinessHour.fromJson` — so the
/// live-backend check below doesn't just exercise the same normalization
/// step twice under two names. Same day-of-week/"doble turno"/overnight-shift
/// algorithm as `search_utils.dart`'s `isOpenNow`, deliberately reimplemented
/// here rather than shared.
bool _referenceIsOpenNow(List<Map<String, dynamic>> rawHours, DateTime now) {
  const weekOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final today = weekOrder[now.weekday - 1];
  final yesterday = weekOrder[(now.weekday - 2 + 7) % 7];
  final nowMinutes = now.hour * 60 + now.minute;

  int? minutesOf(String? raw) {
    if (raw == null) return null;
    final tIndex = raw.indexOf('T');
    final timePart = tIndex == -1 ? raw : raw.substring(tIndex + 1);
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(timePart);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  for (final row in rawHours.where((h) => h['day_of_week'] == today)) {
    if (row['closed'] == true) continue;
    final opens = minutesOf(row['opens_at'] as String?);
    final closes = minutesOf(row['closes_at'] as String?);
    if (opens == null || closes == null) continue;
    final effectiveCloses = closes <= opens ? 1440 : closes;
    if (nowMinutes >= opens && nowMinutes < effectiveCloses) return true;
  }
  for (final row in rawHours.where((h) => h['day_of_week'] == yesterday)) {
    if (row['closed'] == true) continue;
    final opens = minutesOf(row['opens_at'] as String?);
    final closes = minutesOf(row['closes_at'] as String?);
    if (opens == null || closes == null) continue;
    final wrapsPastMidnight = closes > 0 && closes <= opens;
    if (wrapsPastMidnight && nowMinutes < closes) return true;
  }
  return false;
}

const List<DayOfWeek> _weekOrder = [
  DayOfWeek.monday,
  DayOfWeek.tuesday,
  DayOfWeek.wednesday,
  DayOfWeek.thursday,
  DayOfWeek.friday,
  DayOfWeek.saturday,
  DayOfWeek.sunday,
];

/// Parses an already-normalized `"HH:MM:SS"` string (post
/// `BusinessHour.fromJson`) into minutes-since-midnight.
int? _minutesOfHHmmss(String? hhmmss) {
  if (hhmmss == null) return null;
  final parts = hhmmss.split(':');
  if (parts.length < 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  return hours * 60 + minutes;
}

/// The nearest upcoming (or today's) real calendar date whose weekday is
/// [day], at [minutesOfDay] past midnight — lets a test assert against a
/// specific real business_hours weekday without depending on which weekday
/// it happens to be when the test actually runs.
DateTime _dateTimeForWeekdayAt(DayOfWeek day, int minutesOfDay) {
  final targetIsoWeekday = _weekOrder.indexOf(day) + 1; // Monday == 1.
  final now = DateTime.now();
  final daysToAdd = (targetIsoWeekday - now.weekday + 7) % 7;
  final base = now.add(Duration(days: daysToAdd));
  return DateTime(
    base.year,
    base.month,
    base.day,
  ).add(Duration(minutes: minutesOfDay));
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

        // 3b. getAllMenuItems() (the "Platos" result mode's data source)
        // returns real cross-merchant menu items, not mock/fixture data —
        // every item's merchantId must belong to a real seeded merchant.
        final allMenuItems = await remoteDataSource.getAllMenuItems();
        expect(allMenuItems, isNotEmpty);
        final merchantIds = merchants.map((m) => m.id).toSet();
        expect(
          allMenuItems.every((item) => merchantIds.contains(item.merchantId)),
          isTrue,
        );

        // 3c. getBusinessHoursByMerchant()/getLoyaltyRulesByMerchant() (the
        // "Abierto ahora"/"Solo con premio de fidelización disponible"
        // filters' bulk data source) return real data in one fetch each,
        // matching the per-merchant scoped calls for a real merchant.
        final businessHoursByMerchant = await remoteDataSource
            .getBusinessHoursByMerchant();
        final loyaltyRulesByMerchant = await remoteDataSource
            .getLoyaltyRulesByMerchant();
        expect(businessHoursByMerchant, isNotEmpty);
        expect(loyaltyRulesByMerchant, isNotEmpty);

        final firstMerchantId = merchants.first.id;
        final scopedHours = await remoteDataSource.getBusinessHours(
          firstMerchantId,
        );
        expect(
          businessHoursByMerchant[firstMerchantId]?.length,
          scopedHours.length,
        );
        final scopedRules = await remoteDataSource.getLoyaltyRules(
          firstMerchantId,
        );
        expect(
          loyaltyRulesByMerchant[firstMerchantId]?.length,
          scopedRules.length,
        );

        // 3d. `BusinessHour.fromJson` must have normalized the live API's
        // `opens_at`/`closes_at` down to bare `"HH:MM:SS"` — confirmed live
        // (via `curl`) that this backend actually serializes a `time
        // without time zone` column as a full ISO 8601 datetime anchored to
        // a dummy date (`"2000-01-01T18:00:00.000Z"`), not a bare time. A
        // value still containing `"T"` here means that normalization
        // regressed, which would make every downstream open/closed check
        // (`isOpenNow` below, and `restaurant_detail_screen.dart`'s
        // `_computeOpenStatus`) silently fail to parse the hour and treat
        // every merchant as closed, always — this assertion catches that
        // directly, independent of the real wall-clock time.
        final anyRealHour = businessHoursByMerchant.values
            .expand((hours) => hours)
            .firstWhere((h) => !h.closed && h.opensAt != null);
        expect(anyRealHour.opensAt, isNot(contains('T')));
        expect(anyRealHour.opensAt, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));

        // The real case this whole method exists for — confirmed against
        // the actual running backend, not a canned fixture: pick one real
        // merchant, independently work out "is it open right now" straight
        // from a fresh raw HTTP response (bypassing `BusinessHour.fromJson`
        // entirely, so this doesn't just re-check the same normalization
        // step twice), and confirm `isOpenNow`/`applySearchFilters` agree —
        // then confirm the filter's actual output (open merchants only)
        // matches that same ground truth across every merchant.
        final now = DateTime.now();
        final referenceMerchant = merchants.first;
        final rawHoursResponse = await dio.get<Map<String, dynamic>>(
          '/business_hours',
          queryParameters: {'merchant_id': referenceMerchant.id, 'page': 1},
        );
        final rawHours =
            (rawHoursResponse.data?['data'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
        final expectedOpen = _referenceIsOpenNow(rawHours, now);
        final actualOpen = isOpenNow(
          businessHoursByMerchant[referenceMerchant.id] ?? const [],
          now,
        );
        expect(
          actualOpen,
          expectedOpen,
          reason:
              'isOpenNow() disagreed with an independent computation from '
              'the raw (non-normalized) API response for merchant '
              '${referenceMerchant.id} at $now',
        );

        final openNowResults = applySearchFilters(
          merchants,
          const SearchFilters(openNowOnly: true),
          businessHoursByMerchant: businessHoursByMerchant,
          now: now,
        );
        expect(
          openNowResults.any((m) => m.id == referenceMerchant.id),
          expectedOpen,
          reason:
              'applySearchFilters(openNowOnly: true) disagreed with the '
              'reference merchant\'s real open/closed status',
        );
        // The filter never returns a merchant `isOpenNow` says is closed —
        // the actual "Abierto ahora" toggle's real-data guarantee.
        expect(
          openNowResults.every(
            (m) => isOpenNow(businessHoursByMerchant[m.id] ?? const [], now),
          ),
          isTrue,
        );

        // Whatever time this test happens to run, seeded restaurant hours
        // may all be closed right now (e.g. 6am) — that alone wouldn't
        // distinguish "the fix works" from "coincidentally everything's
        // closed anyway". So also prove BOTH a real "open" and a real
        // "closed" verdict deterministically: scan the real (normalized)
        // `businessHoursByMerchant` data for one plain same-day shift (no
        // overnight wrap — mid-shift is unambiguously open) and one day a
        // real merchant marked fully `closed: true`, then evaluate
        // `isOpenNow` at a synthetic instant on that exact real weekday.
        ({int merchantId, DayOfWeek day, int opens, int closes})? openSample;
        ({int merchantId, DayOfWeek day})? closedSample;
        outer:
        for (final entry in businessHoursByMerchant.entries) {
          for (final hour in entry.value) {
            if (hour.closed) {
              closedSample ??= (merchantId: entry.key, day: hour.dayOfWeek);
              continue;
            }
            final opens = _minutesOfHHmmss(hour.opensAt);
            final closes = _minutesOfHHmmss(hour.closesAt);
            if (opens != null && closes != null && closes > opens) {
              openSample ??= (
                merchantId: entry.key,
                day: hour.dayOfWeek,
                opens: opens,
                closes: closes,
              );
            }
          }
          if (openSample != null && closedSample != null) break outer;
        }

        expect(
          openSample,
          isNotNull,
          reason:
              'expected at least one real merchant with a plain same-day '
              'business_hours row (no overnight wrap) to prove the "open" '
              'case deterministically',
        );
        final resolvedOpenSample = openSample!;
        final midShiftMinutes =
            (resolvedOpenSample.opens + resolvedOpenSample.closes) ~/ 2;
        final openInstant = _dateTimeForWeekdayAt(
          resolvedOpenSample.day,
          midShiftMinutes,
        );
        expect(
          isOpenNow(
            businessHoursByMerchant[resolvedOpenSample.merchantId]!,
            openInstant,
          ),
          isTrue,
          reason:
              'merchant ${resolvedOpenSample.merchantId} should read as '
              'open at $openInstant — mid-shift on a real, same-day '
              'business_hours row fetched from the live backend',
        );

        if (closedSample != null) {
          final closedInstant = _dateTimeForWeekdayAt(
            closedSample.day,
            12 * 60,
          );
          expect(
            isOpenNow(
              businessHoursByMerchant[closedSample.merchantId]!,
              closedInstant,
            ),
            isFalse,
            reason:
                'merchant ${closedSample.merchantId} should read as closed '
                'at $closedInstant — a real business_hours row explicitly '
                'marked closed: true for that day',
          );
        }

        // 3e. Same live-data sanity check for `hasAvailableReward`: real
        // consumer with real visit_summaries/loyalty_rules data.
        final anyRewardAvailable = merchants.any(
          (m) => hasAvailableReward(
            loyaltyRulesByMerchant[m.id] ?? const [],
            0, // A merchant this consumer never visited has 0 visits.
          ),
        );
        // No `loyalty_rules` row seeded with `visits_required: 0`, so a
        // never-visited merchant must never read as "reward available".
        expect(anyRewardAvailable, isFalse);

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
