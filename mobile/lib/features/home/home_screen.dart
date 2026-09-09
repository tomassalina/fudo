import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/tag.dart';
import '../../data/providers.dart';
import '../search/widgets/search_home_view.dart';
import '../search/widgets/search_loading_view.dart';
import '../search/widgets/search_utils.dart';
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
///
/// Submitting a query here calls the REAL Gemini-backed backend
/// (`POST /api/v1/search`, `DataSource.parseSearchQuery` — see
/// `data/remote/remote_data_source.dart`), same as web's
/// `AiSearchResolver.tsx` -> `resolveAiSearchFilters` -> `parseSearchQuery`
/// flow, then hands the resolved filters off to [SearchScreen] via
/// `go_router`'s `extra` (see `core/router/app_router.dart`). Public call —
/// no login required to submit it, matching the backend's own public/
/// unauthenticated rule for `POST /api/v1/search` — the search SCREEN
/// itself still applies its own existing login gate once we land there
/// (`features/search/search_screen.dart`'s `isLoggedInProvider` check),
/// unaffected by this change.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.onOpenMerchant, super.key});

  /// Kept for `core/router/app_router.dart` call-site compatibility even
  /// though this screen no longer renders a merchant grid of its own.
  final ValueChanged<int> onOpenMerchant;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Non-null while a `POST /api/v1/search` call is in flight — swaps the
  /// hero's search card for [SearchLoadingView] (same skeleton the "Buscar"
  /// tab itself uses between submitting a query and seeing results) so the
  /// visitor isn't left staring at a dead search box while Gemini resolves
  /// the query, mirroring web's `AiSearchResolver` skeleton.
  String? _pendingQuery;

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
              child: _pendingQuery == null
                  ? SearchHomeView(onSearch: _submitSearch)
                  : SearchLoadingView(query: _pendingQuery!),
            ),
          ],
        ),
      ),
    );
  }

  /// Calls the real backend, then hands off into [AppRoutes.search] with
  /// the resolved filters pre-applied — the search screen's own
  /// `_applyAiSearchResult` (see `search_screen.dart`) does the actual
  /// "loading -> list" transition and analytics tracking from there, so
  /// this only tracks/handles the AI-resolution step itself.
  ///
  /// On any failure (network error, Gemini itself erroring/timing out —
  /// `SearchQueryParser::GeminiError`/`ConfigurationError` on the backend,
  /// surfaced here as a thrown [DioException]), this degrades to a plain
  /// free-text handoff with the visitor's original query and no structured
  /// filters — same posture as web's `AiSearchResolver.tsx` catch branch:
  /// a plain-text result is a complete, useful outcome, not a dead end.
  Future<void> _submitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _pendingQuery = trimmed);
    final dataSource = ref.read(dataSourceProvider);

    SearchScreenInitial resolved;
    try {
      final filters = await dataSource.parseSearchQuery(trimmed);
      var allTags = const <Tag>[];
      try {
        allTags = await dataSource.getTags();
      } catch (_) {
        // Tag lookup is best-effort only (used to resolve Gemini's tag
        // *names* into this app's tag *ids* for the "dieta" filter) — a
        // failure here must not sink an otherwise-successful AI search.
      }
      resolved = mapSearchQueryFiltersToInitial(filters, allTags);
    } catch (_) {
      resolved = SearchScreenInitial(query: trimmed);
    }

    if (!mounted) return;
    setState(() => _pendingQuery = null);
    context.go(AppRoutes.search, extra: resolved);
  }
}
