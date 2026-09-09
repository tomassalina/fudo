import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../search/widgets/search_home_view.dart';
import 'widgets/home_header.dart';

/// "Inicio" tab — mirrors the current `web/app/(marketing)/page.tsx`: just
/// the header plus the AI search hero, no featured-merchants section below
/// it. That web page's own header comment is explicit about this: "Home is
/// intentionally just the hero: no featured-merchants section below it
/// (see FeaturedGrid, still used nowhere but kept around in case it's
/// reused elsewhere — this page just doesn't render it)". `widgets/
/// featured_grid.dart` is kept for the same reason and, like the web side,
/// simply isn't imported here anymore.
///
/// The hero itself reuses [SearchHomeView] — the exact same headline copy,
/// typewriter hints (`web/lib/mock/search.ts`'s `SEARCH_EXAMPLES`) and
/// search-card styling the "Buscar" tab's own landing already implements —
/// instead of re-implementing a second copy of it, since web's home hero
/// (`components/features/home/HeroSearch.tsx`) and that existing landing
/// are the same design now.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onOpenMerchant, super.key});

  /// Kept for `core/router/app_router.dart` call-site compatibility even
  /// though this screen no longer renders a merchant grid of its own.
  final ValueChanged<int> onOpenMerchant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: HomeHeader(),
            ),
            Expanded(
              child: SearchHomeView(
                onSearch: (query) => _submitSearch(context, query),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Same redirect-to-search-with-resolved-query flow as web's
  /// `HeroSearch.tsx` (`router.push('/buscar?ai=' + query)`): `ai` (not
  /// `q`) so the destination screen treats it as a prompt for the AI/
  /// structured-output filter parser rather than a plain name match.
  void _submitSearch(BuildContext context, String query) {
    final uri = Uri(path: AppRoutes.search, queryParameters: {'ai': query});
    context.go(uri.toString());
  }
}
