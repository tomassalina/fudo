// Pure unit tests for `search_utils.dart`'s "Abierto ahora"/"Solo con
// premio de fidelización disponible" plumbing: `isOpenNow`,
// `hasAvailableReward`, and their wiring into `applySearchFilters`.
//
// Deliberately not a widget test — every input here is a hand-built model,
// not the JSON fixtures, so this stays deterministic (no dependency on the
// real wall clock or on `rootBundle` asset loading).

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models/business_hour.dart';
import 'package:mobile/data/models/loyalty_rule.dart';
import 'package:mobile/data/models/merchant.dart';
import 'package:mobile/features/search/widgets/search_utils.dart';

Merchant _merchant(int id) {
  return Merchant(
    id: id,
    name: 'Merchant $id',
    type: MerchantType.restaurant,
    address: 'Calle Falsa 123',
    country: 'Argentina',
    state: 'CABA',
    city: 'Buenos Aires',
    latitude: -34.58,
    longitude: -58.43,
  );
}

BusinessHour _hour({
  required int merchantId,
  required DayOfWeek day,
  String? opensAt,
  String? closesAt,
  bool closed = false,
}) {
  return BusinessHour(
    id: merchantId * 1000 + day.index,
    merchantId: merchantId,
    dayOfWeek: day,
    opensAt: opensAt,
    closesAt: closesAt,
    closed: closed,
  );
}

LoyaltyRule _rule({required int merchantId, required int visitsRequired}) {
  return LoyaltyRule(
    id: merchantId * 1000 + visitsRequired,
    merchantId: merchantId,
    visitsRequired: visitsRequired,
    rewardType: RewardType.freeItem,
    rewardDescription: 'Reward',
    isPermanent: false,
  );
}

void main() {
  group('isOpenNow', () {
    test('true when now falls inside a same-day shift', () {
      final hours = [
        _hour(
          merchantId: 1,
          day: DayOfWeek.monday,
          opensAt: '12:00:00',
          closesAt: '15:30:00',
        ),
      ];
      // 2026-09-07 is a Monday.
      expect(isOpenNow(hours, DateTime(2026, 9, 7, 13, 0)), isTrue);
    });

    test('false when now falls between two shifts (doble turno gap)', () {
      final hours = [
        _hour(
          merchantId: 1,
          day: DayOfWeek.monday,
          opensAt: '12:00:00',
          closesAt: '15:30:00',
        ),
        _hour(
          merchantId: 1,
          day: DayOfWeek.monday,
          opensAt: '20:00:00',
          closesAt: '00:00:00',
        ),
      ];
      expect(isOpenNow(hours, DateTime(2026, 9, 7, 18, 0)), isFalse);
    });

    test('closes_at "00:00:00" means open until end of day, not wrapping', () {
      final hours = [
        _hour(
          merchantId: 1,
          day: DayOfWeek.saturday,
          opensAt: '12:00:00',
          closesAt: '00:00:00',
        ),
      ];
      // 2026-09-12 is a Saturday.
      expect(isOpenNow(hours, DateTime(2026, 9, 12, 23, 30)), isTrue);
    });

    test(
      'a genuine overnight shift (opens 22:00, closes 02:00) is still open '
      'early the next morning',
      () {
        final hours = [
          _hour(
            merchantId: 1,
            day: DayOfWeek.friday,
            opensAt: '22:00:00',
            closesAt: '02:00:00',
          ),
        ];
        // 2026-09-11 is a Friday; 2026-09-12 01:00 is early Saturday morning,
        // still inside Friday night's shift.
        expect(isOpenNow(hours, DateTime(2026, 9, 12, 1, 0)), isTrue);
        // But by 03:00 the shift has ended.
        expect(isOpenNow(hours, DateTime(2026, 9, 12, 3, 0)), isFalse);
      },
    );

    test('a closed row is never open, even during its nominal hours', () {
      final hours = [
        _hour(
          merchantId: 1,
          day: DayOfWeek.monday,
          opensAt: '12:00:00',
          closesAt: '15:30:00',
          closed: true,
        ),
      ];
      expect(isOpenNow(hours, DateTime(2026, 9, 7, 13, 0)), isFalse);
    });

    test('no hours at all means closed', () {
      expect(isOpenNow(const [], DateTime(2026, 9, 7, 13, 0)), isFalse);
    });
  });

  group('hasAvailableReward', () {
    test('true once the visit count reaches the lowest threshold', () {
      final rules = [
        _rule(merchantId: 1, visitsRequired: 2),
        _rule(merchantId: 1, visitsRequired: 4),
      ];
      expect(hasAvailableReward(rules, 2), isTrue);
      expect(hasAvailableReward(rules, 3), isTrue);
    });

    test('false below every threshold, or with no rules at all', () {
      final rules = [_rule(merchantId: 1, visitsRequired: 2)];
      expect(hasAvailableReward(rules, 1), isFalse);
      expect(hasAvailableReward(rules, 0), isFalse);
      expect(hasAvailableReward(const [], 10), isFalse);
    });
  });

  group('applySearchFilters — openNowOnly / rewardAvailableOnly', () {
    test('openNowOnly keeps only merchants open at the given time', () {
      final merchants = [_merchant(1), _merchant(2)];
      final hoursByMerchant = {
        1: [
          _hour(
            merchantId: 1,
            day: DayOfWeek.monday,
            opensAt: '12:00:00',
            closesAt: '15:30:00',
          ),
        ],
        2: [
          _hour(
            merchantId: 2,
            day: DayOfWeek.monday,
            opensAt: '20:00:00',
            closesAt: '23:00:00',
          ),
        ],
      };

      final result = applySearchFilters(
        merchants,
        const SearchFilters(openNowOnly: true),
        businessHoursByMerchant: hoursByMerchant,
        now: DateTime(2026, 9, 7, 13, 0),
      );

      expect(result.map((m) => m.id), [1]);
    });

    test(
      'rewardAvailableOnly keeps only merchants that reached a loyalty '
      'ladder threshold',
      () {
        final merchants = [_merchant(1), _merchant(2)];
        final rulesByMerchant = {
          1: [_rule(merchantId: 1, visitsRequired: 2)],
          2: [_rule(merchantId: 2, visitsRequired: 5)],
        };
        final visitCounts = {1: 3, 2: 1};

        final result = applySearchFilters(
          merchants,
          const SearchFilters(rewardAvailableOnly: true),
          loyaltyRulesByMerchant: rulesByMerchant,
          visitCountsByMerchant: visitCounts,
        );

        expect(result.map((m) => m.id), [1]);
      },
    );

    test(
      'a merchant missing from the bulk maps is treated as closed/no '
      'rewards, not silently kept in',
      () {
        final merchants = [_merchant(1)];

        final openResult = applySearchFilters(
          merchants,
          const SearchFilters(openNowOnly: true),
          now: DateTime(2026, 9, 7, 13, 0),
        );
        expect(openResult, isEmpty);

        final rewardResult = applySearchFilters(
          merchants,
          const SearchFilters(rewardAvailableOnly: true),
        );
        expect(rewardResult, isEmpty);
      },
    );

    test('both filters off leaves every merchant in, regardless of the maps', () {
      final merchants = [_merchant(1), _merchant(2)];

      final result = applySearchFilters(merchants, const SearchFilters());

      expect(result.map((m) => m.id), [1, 2]);
    });
  });
}
