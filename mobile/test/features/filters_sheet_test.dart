// Widget tests for `FiltersSheet` (design brief §2.9).
//
// Same asset-loading workaround as `restaurant_detail_screen_test.dart`:
// pre-warm a `LocalDataSource` in `setUpAll` (outside the per-test test
// binding zone, where a raw `rootBundle.loadString` reliably hangs when
// first awaited from inside `testWidgets`) and override `dataSourceProvider`
// with it, so the widget tree only ever reads already-cached fixture data.
//
// A category's own `merchantsProvider`/`tagsProvider` watch only starts the
// first time that category is built (Precio/Ubicación, not Básico) — like
// every other `FutureProvider` in this app, resolving it still needs one
// extra `pump()` even though the underlying data is already cached, so
// `_tapCategory` always pumps twice.
//
// Chips inside the scrollable category body aren't guaranteed to already be
// within the sheet's visible viewport, so `_tapText` always calls
// `ensureVisible` first — tapping an off-screen chip fails a `hitTestable`
// check instead of registering the tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/models/merchant.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/search/widgets/filters_sheet.dart';
import 'package:mobile/features/search/widgets/search_utils.dart';

late LocalDataSource _warmDataSource;

Future<void> _pumpSheet(
  WidgetTester tester, {
  SearchFilters initialFilters = const SearchFilters(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: FiltersSheet(initialFilters: initialFilters)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  // `warnIfMissed: false`: Flutter's diagnostic-only hit test check is a
  // known false positive here — it runs against a slightly different
  // coordinate frame than the real event dispatch for content inside a
  // `SingleChildScrollView` nested in an animated modal route. The actual
  // tap lands correctly (every test below asserts on its effect), so the
  // warning is just noise, not a real miss.
  await tester.tap(finder, warnIfMissed: false);
}

Future<void> _tapCategory(WidgetTester tester, String label) async {
  await _tapText(tester, label);
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dataSource = LocalDataSource();
    await dataSource.getMerchants();
    await dataSource.getTags();
    await dataSource.getMerchantTagIdsByMerchant();
    await dataSource.getBusinessHoursByMerchant();
    await dataSource.getLoyaltyRulesByMerchant();
    _warmDataSource = dataSource;
  });

  testWidgets('shows all 5 filter categories from the design brief', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('Básico'), findsOneWidget);
    // "Precio" is both a category tab and a sort-option chip on "Básico"
    // (design brief's own "orden ... precio"), so it appears twice here.
    expect(find.text('Precio'), findsWidgets);
    expect(find.text('Platos'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);
    expect(find.text('Premios'), findsOneWidget);
  });

  testWidgets(
    'opens on "Básico" with no filters active and the "Ocultar visitados" '
    'toggle always visible',
    (tester) async {
      await _pumpSheet(tester);

      // `_ActiveCountPill` always renders the numeral count now (matching
      // web's `PhoneFilterSheet.tsx` exactly), including "0 filtros
      // activos" — the old bottom-of-sheet "Sin filtros activos" special
      // case for 0 this test used to check doesn't exist anymore (see the
      // doc comment on `_ActiveCountPill`).
      expect(find.text('0 filtros activos'), findsOneWidget);
      expect(find.text('ORDENAR POR'), findsOneWidget);
      expect(find.text('TIPO DE LOCAL'), findsOneWidget);
      expect(find.text('Abierto ahora'), findsOneWidget);
      expect(find.text('Ocultar visitados'), findsOneWidget);
    },
  );

  testWidgets(
    '"Abierto ahora" is a real, enabled toggle — not the disabled '
    '"Próximamente" placeholder from before the bulk business-hours data '
    'source method existed — and bumps activeCount like any other filter',
    (tester) async {
      await _pumpSheet(tester);

      // No "Próximamente" badge anywhere on Básico anymore.
      expect(find.text('Próximamente'), findsNothing);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, isNotEmpty);
      expect(switches.every((s) => s.onChanged != null), isTrue);

      // "Abierto ahora" is the first Switch in the tree — the category
      // body renders above the always-visible "Ocultar visitados" toggle.
      // It sits below several rows of chips, so (like `_tapText`) it needs
      // `ensureVisible` before it can be hit-tested inside the scrollable
      // category body.
      final abiertoAhoraSwitch = find.byType(Switch).first;
      await tester.ensureVisible(abiertoAhoraSwitch);
      await tester.pumpAndSettle();
      await tester.tap(abiertoAhoraSwitch, warnIfMissed: false);
      await tester.pump();
      expect(find.text('1 filtro activo'), findsOneWidget);
    },
  );

  testWidgets(
    '"Solo con premio de fidelización disponible" (Premios) is a real, '
    'enabled toggle — same regression coverage as "Abierto ahora" above',
    (tester) async {
      await _pumpSheet(tester);

      await tester.tap(find.text('Premios'));
      await tester.pumpAndSettle();

      expect(find.text('Próximamente'), findsNothing);
      final premiosSwitchFinder = find.byType(Switch).first;
      expect(
        tester.widget<Switch>(premiosSwitchFinder).onChanged,
        isNotNull,
      );

      await tester.ensureVisible(premiosSwitchFinder);
      await tester.pumpAndSettle();
      await tester.tap(premiosSwitchFinder, warnIfMissed: false);
      await tester.pump();
      expect(find.text('1 filtro activo'), findsOneWidget);
    },
  );

  testWidgets(
    'applying a merchant-type filter bumps activeCount to 1 and the count '
    'copy pluralizes correctly',
    (tester) async {
      await _pumpSheet(tester);

      await _tapText(tester, merchantTypeLabel(MerchantType.cafe));
      await tester.pump();

      expect(find.text('1 filtro activo'), findsOneWidget);
      expect(find.text('0 filtros activos'), findsNothing);
    },
  );

  testWidgets('tapping the same type chip again clears the filter', (
    tester,
  ) async {
    await _pumpSheet(tester);
    final cafeLabel = merchantTypeLabel(MerchantType.cafe);

    await _tapText(tester, cafeLabel);
    await tester.pump();
    expect(find.text('1 filtro activo'), findsOneWidget);

    await _tapText(tester, cafeLabel);
    await tester.pump();
    expect(find.text('0 filtros activos'), findsOneWidget);
  });

  testWidgets(
    '"Limpiar" resets every active filter back to zero (sort + merchant '
    'type combined)',
    (tester) async {
      await _pumpSheet(tester);

      await _tapText(tester, merchantTypeLabel(MerchantType.cafe));
      await tester.pump();
      await _tapText(tester, SortOption.distance.label);
      await tester.pump();
      expect(find.text('2 filtros activos'), findsOneWidget);

      await _tapText(tester, 'Limpiar');
      await tester.pump();

      expect(find.text('0 filtros activos'), findsOneWidget);
    },
  );

  testWidgets(
    '"Platos" category shows the documented placeholder instead of a '
    'made-up dish filter',
    (tester) async {
      await _pumpSheet(tester);

      await _tapCategory(tester, 'Platos');

      expect(
        find.text('Filtro de platos disponible desde la vista de platos'),
        findsOneWidget,
      );
    },
  );

  testWidgets('"Ubicación" lists real neighborhoods from the fixture', (
    tester,
  ) async {
    await _pumpSheet(tester);

    await _tapCategory(tester, 'Ubicación');

    // "Palermo" is a real neighborhood in assets/fixtures/merchants.json.
    expect(find.text('Palermo'), findsOneWidget);
  });

  testWidgets('opening with a pre-set filter reflects its count immediately', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      initialFilters: const SearchFilters(hideVisited: true),
    );

    expect(find.text('1 filtro activo'), findsOneWidget);
  });

  testWidgets('tapping "Aplicar" pops the sheet with the edited filters', (
    tester,
  ) async {
    SearchFilters? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<SearchFilters>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const FiltersSheet(initialFilters: SearchFilters()),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await _tapText(tester, merchantTypeLabel(MerchantType.bar));
    await tester.pump();

    await _tapText(tester, 'Aplicar');
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.merchantType, MerchantType.bar);
    expect(result!.activeCount, 1);
  });
}
