import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/local/local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDataSource dataSource;

  setUp(() {
    dataSource = LocalDataSource();
  });

  group('LocalDataSource', () {
    test('getMerchants returns a non-empty, parsed merchant list', () async {
      final merchants = await dataSource.getMerchants();

      expect(merchants, isNotEmpty);
      final first = merchants.firstWhere((m) => m.id == 1);
      expect(first.name, 'Don Chile Cantina');
      expect(first.address, isNotEmpty);
      expect(first.latitude, isNot(0));
    });

    test(
      'getMenuItems returns menu items belonging to the given merchant',
      () async {
        const merchantId = 1;
        final items = await dataSource.getMenuItems(merchantId);

        expect(items, isNotEmpty);
        expect(items.every((item) => item.merchantId == merchantId), isTrue);
        expect(items.any((item) => item.name.contains('Tacos')), isTrue);
      },
    );

    test('getMerchants caches results across calls', () async {
      final first = await dataSource.getMerchants();
      final second = await dataSource.getMerchants();

      expect(identical(first, second), isTrue);
    });

    test('getCurrentConsumer returns the demo consumer', () async {
      final consumer = await dataSource.getCurrentConsumer();

      expect(consumer.firstName, 'Martina');
      expect(consumer.hasDniOnFile, isTrue);
    });

    test(
      'getBusinessHoursByMerchant groups every business_hours row by '
      'merchant id, matching getBusinessHours(merchantId) for a real one',
      () async {
        const merchantId = 1;
        final byMerchant = await dataSource.getBusinessHoursByMerchant();
        final scoped = await dataSource.getBusinessHours(merchantId);

        expect(byMerchant, isNotEmpty);
        expect(byMerchant[merchantId], isNotNull);
        expect(byMerchant[merchantId]!.length, scoped.length);
        expect(
          byMerchant[merchantId]!.every((h) => h.merchantId == merchantId),
          isTrue,
        );
      },
    );

    test(
      'getLoyaltyRulesByMerchant groups every loyalty_rules row by merchant '
      'id, matching getLoyaltyRules(merchantId) for a real one',
      () async {
        const merchantId = 1;
        final byMerchant = await dataSource.getLoyaltyRulesByMerchant();
        final scoped = await dataSource.getLoyaltyRules(merchantId);

        expect(byMerchant, isNotEmpty);
        expect(byMerchant[merchantId], isNotNull);
        expect(byMerchant[merchantId]!.length, scoped.length);
        expect(
          byMerchant[merchantId]!.every((r) => r.merchantId == merchantId),
          isTrue,
        );
      },
    );
  });
}
