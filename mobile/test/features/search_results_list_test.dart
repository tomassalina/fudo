// Widget tests for `SearchResultsList`'s advanced-filters integration
// (design brief §2.3/§2.9): confirms `SearchFilters` produced by
// `FiltersSheet` actually narrows/reorders what the list shows, not just
// that the sheet's own `activeCount` changes.
//
// Same asset pre-warming workaround as `filters_sheet_test.dart` /
// `restaurant_detail_screen_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/models/merchant.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/search/widgets/search_results_list.dart';
import 'package:mobile/features/search/widgets/search_utils.dart';

late LocalDataSource _warmDataSource;

Future<void> _pumpList(
  WidgetTester tester, {
  SearchFilters filters = const SearchFilters(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SearchResultsList(
            query: '',
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
    await dataSource.getFavorites();
    await dataSource.getMerchantTagIdsByMerchant();
    await dataSource.getVisitSummaries(merchantId: null);
    _warmDataSource = dataSource;
  });

  testWidgets('with no filters, all 30 fixture merchants match', (
    tester,
  ) async {
    await _pumpList(tester);

    expect(find.text('30 coincidencias'), findsOneWidget);
  });

  testWidgets(
    'a real SearchFilters (merchant type = cafe) narrows the shown results, '
    'matching the 6 cafés in the fixture',
    (tester) async {
      await _pumpList(
        tester,
        filters: const SearchFilters(merchantType: MerchantType.cafe),
      );

      expect(find.text('6 coincidencias'), findsOneWidget);
    },
  );

  testWidgets('a neighborhood filter narrows results to that neighborhood', (
    tester,
  ) async {
    await _pumpList(
      tester,
      filters: const SearchFilters(neighborhood: 'Colegiales'),
    );

    // "Parrilla La Vuelta" (merchant id 4) is the only Colegiales merchant.
    expect(find.text('1 coincidencia'), findsOneWidget);
    expect(find.text('Parrilla La Vuelta'), findsOneWidget);
  });

  testWidgets(
    'combining filters that match nothing shows the "filtros" empty state, '
    'not the text-search empty state',
    (tester) async {
      await _pumpList(
        tester,
        filters: const SearchFilters(
          merchantType: MerchantType.cafe,
          neighborhood: 'Chacarita', // Chacarita's only merchant is a bar.
        ),
      );

      expect(find.text('Ningún lugar con esos filtros'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);
    },
  );
}
