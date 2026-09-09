// Widget tests for `MyPlacesScreen` (design brief §2.7, backlog item 9).
//
// Same environment workaround as `test/features/restaurant_detail_screen_test.dart`:
// `rootBundle.loadString` for the fixtures reliably hangs when first awaited
// *inside* a `testWidgets` body in this environment, so a single
// `LocalDataSource` is pre-warmed once in `setUpAll` (awaiting every method
// the screen needs) and injected via `dataSourceProvider.overrideWithValue`.
//
// Stale-test correction: the login form used to have a decorative
// "Continuar con Google" mock button (with an "o con email" divider under
// it) that just showed a disclaimer snackbar instead of doing anything real
// — that whole block is gone from `my_places_screen.dart`'s
// `_LoggedOutView.build` now. The form's own comment on the "Registrate"
// button explains why: this screen's auth used to be entirely mocked, and
// was wired up to the real `AuthRepository` instead ("used to be a mock
// snackbar even though `AuthRepository.register()` already worked against
// the real backend"). The dedicated "Continuar con Google is a decorative
// mock" test this file used to have tested exactly that removed mock flow,
// so it's gone too — there's no real replacement to assert on on the local/
// `ConnectionMode.local` path this file exercises (still "100% fake login"
// per `_onLoginPressed`'s own doc comment, just without the Google button);
// `test/features/my_places_screen_remote_login_test.dart` already covers
// the real `ConnectionMode.remote` login path this screen now has.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/providers.dart';
import 'package:mobile/features/my_places/my_places_screen.dart';

late LocalDataSource _warmDataSource;

Future<void> _pumpMyPlacesScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataSourceProvider.overrideWithValue(_warmDataSource)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const MyPlacesScreen(),
      ),
    ),
  );

  // Even with the data source pre-warmed, a couple of pumps flush the
  // now-synchronous-ish `FutureProvider` microtasks so loading spinners
  // resolve to real content (same pattern as the restaurant detail test).
  await tester.pump();
  await tester.pump();
}

Future<void> _logIn(WidgetTester tester) async {
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dataSource = LocalDataSource();
    await dataSource.getCurrentConsumer();
    await dataSource.getConsumerSettings();
    await dataSource.getMerchants();
    await dataSource.getVisitSummaries();
    await dataSource.getFavorites();
    _warmDataSource = dataSource;
  });

  group('logged-out state', () {
    testWidgets('shows the email/password login form', (tester) async {
      await _pumpMyPlacesScreen(tester);

      expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);
      expect(find.text('tu@email.com'), findsOneWidget);
      expect(find.text('Tu contraseña'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('¿No tenés cuenta? Registrate'), findsOneWidget);

      // No sub-tabs / profile content until "logged in".
      expect(find.text('Visitas'), findsNothing);
      expect(find.text('Favoritos'), findsNothing);
      expect(find.text('Ajustes'), findsNothing);
    });
  });

  group('logging in', () {
    testWidgets(
      'tapping "Iniciar sesión" logs in (no validation) and shows the '
      "fixture consumer's name",
      (tester) async {
        await _pumpMyPlacesScreen(tester);
        await _logIn(tester);

        // Fixture: assets/fixtures/consumers.json -> Martina Giménez.
        expect(find.text('Martina Giménez'), findsOneWidget);
        expect(
          find.text('martina.gimenez@example.com'),
          findsOneWidget,
        );
        // Login form is gone.
        expect(find.text('Ingresá a tu cuenta de Fudo'), findsNothing);
      },
    );

    testWidgets('shows the consumer\'s top loyalty tier badge', (
      tester,
    ) async {
      await _pumpMyPlacesScreen(tester);
      await _logIn(tester);

      // Fixture: visit_summaries.json has counts [3, 4, 6, 7, 9] across
      // merchants for this consumer — the max (9) falls in the >=8 "NIVEL
      // ORO" bucket of TIERS_L (design brief §1), which must be the
      // consumer's *top* tier badge, not e.g. "NIVEL PLATA" from a lower
      // per-merchant count.
      expect(find.text('NIVEL ORO'), findsOneWidget);
    });
  });

  group('logged-in sub-tabs', () {
    testWidgets('all 3 sub-tabs exist and switch content on tap', (
      tester,
    ) async {
      await _pumpMyPlacesScreen(tester);
      await _logIn(tester);

      expect(find.text('Visitas'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);

      // Visitas is selected by default.
      expect(find.text('LUGARES QUE VISITASTE'), findsOneWidget);

      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('TUS FAVORITOS'), findsOneWidget);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('DATOS PERSONALES'), findsOneWidget);
      expect(find.text('PREFERENCIAS'), findsOneWidget);

      // Ajustes' ListView is taller than the test surface — "SEGURIDAD Y
      // CUENTA" is further down and isn't mounted until scrolled into the
      // list's cache extent, same reasoning as the restaurant detail test's
      // `_scrollUntilVisible`. The Ajustes tab's own ListView (not the
      // TabBarView's internal PageView, also a Scrollable) is the last one
      // in the tree once this tab is selected and settled.
      await tester.scrollUntilVisible(
        find.text('SEGURIDAD Y CUENTA'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('SEGURIDAD Y CUENTA'), findsOneWidget);
    });

    testWidgets('Favoritos shows the fixture favorites, not the empty state', (
      tester,
    ) async {
      await _pumpMyPlacesScreen(tester);
      await _logIn(tester);

      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();

      // The demo consumer's favoriteIdsProvider seeds from favorites.json,
      // which has entries — so the empty state should NOT show.
      expect(find.text('TUS FAVORITOS'), findsOneWidget);
      expect(
        find.text('Marcá lugares con el corazón y aparecen acá.'),
        findsNothing,
      );
    });
  });

  group('cerrar sesión', () {
    testWidgets('logs out back to the login form', (tester) async {
      await _pumpMyPlacesScreen(tester);
      await _logIn(tester);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);
      expect(find.text('Martina Giménez'), findsNothing);
    });
  });

  group('eliminar cuenta double-tap confirm', () {
    testWidgets(
      'first tap arms the confirmation, second tap logs out',
      (tester) async {
        await _pumpMyPlacesScreen(tester);
        await _logIn(tester);

        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Eliminar cuenta'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Eliminar cuenta'));
        await tester.pump();

        expect(find.text('Tocá de nuevo para confirmar'), findsOneWidget);
        expect(find.text('Ingresá a tu cuenta de Fudo'), findsNothing);

        await tester.tap(find.text('Tocá de nuevo para confirmar'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);
      },
    );

    testWidgets(
      'deleting the account drops in-memory personal-data edits, unlike '
      'just logging out (regression: found by review — delete used to be '
      'a plain logOut() alias that left the edited name behind)',
      (tester) async {
        await _pumpMyPlacesScreen(tester);
        await _logIn(tester);

        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();

        // Edit "Nombre" from the fixture's "Martina" to something else.
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Martina'),
          'Cambiada',
        );
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        expect(find.text('Cambiada'), findsOneWidget);

        // Delete the account (double-tap confirm).
        await tester.scrollUntilVisible(
          find.text('Eliminar cuenta'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Eliminar cuenta'));
        await tester.pump();
        await tester.tap(find.text('Tocá de nuevo para confirmar'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Ingresá a tu cuenta de Fudo'), findsOneWidget);

        // Log back in as the same demo consumer — the edit must be gone.
        await _logIn(tester);
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();

        expect(find.text('Cambiada'), findsNothing);
        expect(find.text('Martina'), findsOneWidget);
      },
    );
  });
}
