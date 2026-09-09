import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/auth/register_screen.dart';
import '../../features/gifting/gifting_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/my_places/my_places_screen.dart';
import '../../features/search/restaurant_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/search/widgets/search_utils.dart';
import '../../shared/widgets/main_shell.dart';

/// Bottom nav tab order: Inicio (0), Buscar (1), Mis Lugares (2), Regalar
/// (3).
class AppRoutes {
  AppRoutes._();

  static const String home = '/home';
  static const String search = '/search';
  static const String myPlaces = '/my-places';
  static const String gifting = '/gifting';

  /// Registro real (`features/auth/register_screen.dart`) — full-screen
  /// route outside the bottom-nav shell, reached from `MyPlacesScreen`'s
  /// "¿No tenés cuenta? Registrate" link (Tarea 4).
  static const String register = '/register';

  /// Restaurant detail — full-screen route outside the bottom-nav shell
  /// (the design's detail view has no bottom nav, just back/favorite
  /// buttons over the photo header). Reached from search results and the
  /// map, regardless of which tab is active.
  static String merchantDetail(int merchantId) => '/merchant/$merchantId';
  static const String merchantDetailPattern = '/merchant/:id';

  static const List<String> _tabOrder = [home, search, myPlaces, gifting];

  static int indexForLocation(String location) {
    final index = _tabOrder.indexWhere((path) => location.startsWith(path));
    return index == -1 ? 0 : index;
  }
}

/// App-wide router. Wraps the main tabs in a [MainShell] with a
/// [BottomNavigationBar] so tab state persists across navigation.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      // Gate the ENTIRE shell chrome behind auth, not just the routed child
      // (unlike search's existing per-screen gate, see
      // `features/search/search_screen.dart` Decisión 37). A logged-out
      // visitor must see no bottom nav at all — only the login screen — so
      // this `Consumer` decides, reactively on [isLoggedInProvider], whether
      // to mount [MainShell] (with the 5-tab nav) or bypass it entirely and
      // render the login form directly. [MyPlacesScreen] already renders
      // just that form (via its own `_LoggedOutView`, no [MainShell]
      // wrapper) when logged out — see commits `129f95b`/`25d2313` — so it's
      // reused here instead of duplicating the login UI.
      builder: (context, state, child) {
        return Consumer(
          builder: (context, ref, _) {
            final isLoggedIn = ref.watch(isLoggedInProvider);
            if (!isLoggedIn) {
              return const MyPlacesScreen();
            }
            final currentIndex = AppRoutes.indexForLocation(
              state.uri.toString(),
            );
            return MainShell(
              currentIndex: currentIndex,
              onTap: (index) => context.go(_locationForIndex(index)),
              child: child,
            );
          },
        );
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => HomeScreen(
            onOpenMerchant: (merchantId) =>
                context.push(AppRoutes.merchantDetail(merchantId)),
          ),
        ),
        GoRoute(
          path: AppRoutes.search,
          // `state.extra` carries a `SearchScreenInitial` when this route
          // was reached from the home hero's AI search (see
          // `features/home/home_screen.dart`'s `_submitSearch`) — `null` for
          // a plain "Buscar" tab switch, in which case [SearchScreen] shows
          // its normal home/search-entry view exactly as before.
          builder: (context, state) =>
              SearchScreen(initial: state.extra as SearchScreenInitial?),
        ),
        GoRoute(
          path: AppRoutes.myPlaces,
          builder: (context, state) => const MyPlacesScreen(),
        ),
        GoRoute(
          path: AppRoutes.gifting,
          builder: (context, state) => const GiftingScreen(),
        ),
      ],
    ),
    // Outside the ShellRoute on purpose: the detail screen replaces the
    // bottom nav with its own back/favorite buttons over the photo header.
    GoRoute(
      path: AppRoutes.merchantDetailPattern,
      builder: (context, state) {
        // int.tryParse (not int.parse): today the only emitter of this
        // route is the typed AppRoutes.merchantDetail(int), but the path is
        // still a plain URL segment — a malformed deep link (or a future
        // external link) with a non-numeric id must not crash the app.
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(
            body: Center(child: Text('Restaurante no encontrado')),
          );
        }
        return RestaurantDetailScreen(merchantId: id);
      },
    ),
    // Outside the ShellRoute too: registering has no bottom nav either.
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
  ],
);

String _locationForIndex(int index) {
  switch (index) {
    case 1:
      return AppRoutes.search;
    case 2:
      return AppRoutes.myPlaces;
    case 3:
      return AppRoutes.gifting;
    case 0:
    default:
      return AppRoutes.home;
  }
}
