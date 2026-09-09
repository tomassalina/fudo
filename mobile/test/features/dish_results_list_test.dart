// Widget tests for `DishResultsList` — the "Buscar" tab's cross-merchant
// "Platos" result mode (design brief §2.9/backlog item 5). Mirrors
// `search_results_list_test.dart`'s pattern: a warm `LocalDataSource`
// override, then assertions on rendered result counts/text.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/models/merchant.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/search/widgets/dish_results_list.dart';
import 'package:mobile/features/search/widgets/search_utils.dart';

late LocalDataSource _warmDataSource;

Future<void> _pumpList(
  WidgetTester tester, {
  String query = '',
  SearchFilters filters = const SearchFilters(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: DishResultsList(
            query: query,
            filters: filters,
            onClearSearch: () {},
            onOpenMerchant: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dataSource = LocalDataSource();
    await dataSource.getMerchants();
    await dataSource.getAllMenuItems();
    await dataSource.getMerchantTagIdsByMerchant();
    await dataSource.getVisitSummaries(merchantId: null);
    _warmDataSource = dataSource;
  });

  testWidgets('with no query or filters, all 150 fixture dishes match', (
    tester,
  ) async {
    await _pumpList(tester);

    expect(find.text('150 platos encontrados'), findsOneWidget);
  });

  testWidgets(
    'a text query matches dish names across merchants (accent/case '
    'insensitive, same as the merchant list)',
    (tester) async {
      await _pumpList(tester, query: 'milanesa');

      // "Milanesa napolitana" + "Milanesa a la napolitana" in the fixture.
      expect(find.text('2 platos encontrados'), findsOneWidget);
    },
  );

  testWidgets(
    'a real SearchFilters (merchant type = cafe) narrows candidate '
    'merchants, matching only dishes served by the 6 café merchants',
    (tester) async {
      await _pumpList(
        tester,
        filters: const SearchFilters(merchantType: MerchantType.cafe),
      );

      expect(find.text('30 platos encontrados'), findsOneWidget);
    },
  );

  testWidgets(
    'combining filters that leave no candidate merchant shows the '
    '"filtros" empty state, not the text-search empty state',
    (tester) async {
      await _pumpList(
        tester,
        filters: const SearchFilters(
          merchantType: MerchantType.cafe,
          neighborhood: 'Chacarita', // Chacarita's only merchant is a bar.
        ),
      );

      expect(find.text('Ningún plato con esos filtros'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);
    },
  );

  testWidgets(
    'a query that matches no dish shows the text-search empty state',
    (tester) async {
      await _pumpList(tester, query: 'zzzznonexistent');

      expect(find.text('Sin platos para "zzzznonexistent"'), findsOneWidget);
      expect(find.text('Limpiar búsqueda'), findsOneWidget);
    },
  );
}
