import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/gifting/gifting_screen.dart';
import '../../features/my_places/my_places_screen.dart';
import '../../features/search/search_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// Bottom nav tab order: Buscar (0), Mis Lugares (1), Regalar (2).
class AppRoutes {
  AppRoutes._();

  static const String search = '/search';
  static const String myPlaces = '/my-places';
  static const String gifting = '/gifting';

  static const List<String> _tabOrder = [search, myPlaces, gifting];

  static int indexForLocation(String location) {
    final index = _tabOrder.indexWhere((path) => location.startsWith(path));
    return index == -1 ? 0 : index;
  }
}

/// App-wide router. Wraps the three main tabs in a [MainShell] with a
/// [BottomNavigationBar] so tab state persists across navigation.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.search,
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final currentIndex = AppRoutes.indexForLocation(state.uri.toString());
        return MainShell(
          currentIndex: currentIndex,
          onTap: (index) => context.go(_locationForIndex(index)),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => const SearchScreen(),
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
  ],
);

String _locationForIndex(int index) {
  switch (index) {
    case 1:
      return AppRoutes.myPlaces;
    case 2:
      return AppRoutes.gifting;
    case 0:
    default:
      return AppRoutes.search;
  }
}
