import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('merchantsProvider resolves the 30 merchants from the fixture', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final merchants = await container.read(merchantsProvider.future);

    expect(merchants, hasLength(30));
  });

  test(
    'businessHoursByMerchantProvider resolves every merchant\'s business '
    'hours in one bulk fetch, matching businessHoursProvider(1) for a real '
    'merchant',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final byMerchant = await container.read(
        businessHoursByMerchantProvider.future,
      );
      final scoped = await container.read(businessHoursProvider(1).future);

      expect(byMerchant, isNotEmpty);
      expect(byMerchant[1]?.length, scoped.length);
    },
  );

  test(
    'loyaltyRulesByMerchantProvider resolves every merchant\'s loyalty '
    'rules in one bulk fetch, matching loyaltyRulesProvider(1) for a real '
    'merchant',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final byMerchant = await container.read(
        loyaltyRulesByMerchantProvider.future,
      );
      final scoped = await container.read(loyaltyRulesProvider(1).future);

      expect(byMerchant, isNotEmpty);
      expect(byMerchant[1]?.length, scoped.length);
    },
  );
}
