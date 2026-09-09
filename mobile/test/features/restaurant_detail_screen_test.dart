// Widget tests for `RestaurantDetailScreen` (design brief §2.5).
//
// Uses merchant id 1 ("Don Chile Cantina") from the real fixtures
// (`assets/fixtures/merchants.json` + friends).
//
// Environment note: `rootBundle.loadString` for the larger fixtures (e.g.
// `menu_items.json`, ~50KB) reliably hangs forever when first awaited
// *inside* a `testWidgets` body in this environment — verified directly
// against a raw `rootBundle.loadString` call, and reproducible with a
// minimal `ConsumerWidget` watching `menuItemsProvider` alone, with no
// relation to this screen's own code (smaller fixtures like
// `business_hours.json` load fine the same way). The same load succeeds
// immediately from `setUpAll` (outside `testWidgets`'s per-test binding
// zone) — matching how `test/data/local_data_source_test.dart` already
// loads every fixture reliably via plain `test()`. So: a single
// `LocalDataSource` is pre-warmed once in `setUpAll` (awaiting every method
// the screen needs, exactly like that file does) and injected via
// `dataSourceProvider.overrideWithValue` — the widget tree then reads
// already-cached lists instead of ever awaiting a fresh asset load itself.
// This is also just good practice regardless of the environment quirk: a
// widget test shouldn't depend on real asset I/O timing to begin with.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/search/restaurant_detail_screen.dart';

late LocalDataSource _warmDataSource;

Future<void> _pumpDetailScreen(
  WidgetTester tester, {
  int merchantId = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: RestaurantDetailScreen(merchantId: merchantId),
      ),
    ),
  );

  // Even with the data source pre-warmed (no real asset I/O left to await),
  // a couple of pumps flush the now-synchronous-ish `FutureProvider`
  // microtasks so the loading spinners resolve to real content.
  await tester.pump();
  await tester.pump();
}

/// The screen's content (photo header + hours + loyalty timeline) is taller
/// than the default test surface, and it's built inside a `CustomScrollView`
/// — slivers only inflate children that fall within the viewport + cache
/// extent, so content below the fold genuinely isn't in the widget tree
/// until scrolled into range. `scrollUntilVisible` reveals it incrementally.
Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dataSource = LocalDataSource();
    await dataSource.getMerchants();
    await dataSource.getBusinessHours(1);
    await dataSource.getLoyaltyRules(1);
    await dataSource.getVisitSummaries(merchantId: 1);
    await dataSource.getFavorites();
    final items = await dataSource.getMenuItems(1);
    for (final item in items) {
      await dataSource.getTagsForMenuItem(item.id);
    }
    _warmDataSource = dataSource;
  });

  testWidgets('renders the merchant name and the sub-tabs', (tester) async {
    await _pumpDetailScreen(tester);

    expect(find.text('Don Chile Cantina'), findsOneWidget);
    expect(find.text('Mis visitas'), findsOneWidget);
    expect(find.text('Menú'), findsOneWidget);
  });

  testWidgets(
    '"Mis visitas" is selected by default and shows loyalty progress',
    (tester) async {
      await _pumpDetailScreen(tester);
      await _scrollUntilVisible(tester, find.text('TU CAMINO EN NIVEL PLATA'));

      // Fixture: visit_summaries.json has count=4 for consumer×merchant 1,
      // and loyalty_rules.json has rules at 2/4/6/8/10 visits — 4 exactly
      // matches a rule, so "ESTÁS ACÁ" must be on that step, and the next
      // unreached rule (6 visits, "Entrada para compartir") gets "PRÓXIMO".
      expect(find.byKey(const ValueKey('loyaltyVisitsCount')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('loyaltyVisitsCount')))
            .data,
        '4',
      );
      expect(find.text('NIVEL PLATA'), findsOneWidget);
      expect(find.text('Falta 1 visita para tu próximo premio'), findsNothing);
      expect(
        find.text('Faltan 2 visitas para tu próximo premio'),
        findsOneWidget,
      );
      expect(find.text('ESTÁS ACÁ'), findsOneWidget);
      expect(find.text('PRÓXIMO'), findsOneWidget);
      expect(find.text('Entrada para compartir'), findsOneWidget);

      // Menú content isn't built yet.
      expect(find.text('Tacos al pastor (3u)'), findsNothing);
    },
  );

  testWidgets('tapping "Menú" shows a real dish from the fixture', (
    tester,
  ) async {
    await _pumpDetailScreen(tester);

    await tester.tap(find.text('Menú'));
    await tester.pump();
    await tester.pump();
    await _scrollUntilVisible(tester, find.text('Tacos al pastor (3u)'));

    expect(find.text('Tacos al pastor (3u)'), findsOneWidget);
    expect(find.text('\$16.000 ARS'), findsOneWidget);

    // Switching tabs away hides the loyalty content.
    expect(find.text('NIVEL PLATA'), findsNothing);
  });

  testWidgets("shows today's open status and expands to the day-by-day list", (
    tester,
  ) async {
    await _pumpDetailScreen(tester);

    // Merchant 1 is open every day (lunch + dinner shifts, or an all-day
    // Sat/Sun shift) with no `closed: true` row, so regardless of the real
    // wall-clock time when this test runs, the status is one of these two
    // literal strings — never a spinner or blank.
    final isOpen = find.text('Abierto ahora');
    final isClosed = find.text('Cerrado');
    expect(
      isOpen.evaluate().isNotEmpty || isClosed.evaluate().isNotEmpty,
      isTrue,
    );

    // Both the collapsed summary and the day-by-day list are always mounted
    // (that's how `AnimatedCrossFade` cross-fades between them) — so
    // "collapsed" is asserted via the widget's `crossFadeState`, not via
    // `find.text('Lunes')` presence/absence.
    AnimatedCrossFade crossFade() =>
        tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));

    expect(crossFade().crossFadeState, CrossFadeState.showFirst);

    await tester.tap(
      find.text(isOpen.evaluate().isNotEmpty ? 'Abierto ahora' : 'Cerrado'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(crossFade().crossFadeState, CrossFadeState.showSecond);
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('Domingo'), findsOneWidget);
  });
}
