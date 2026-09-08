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
}
