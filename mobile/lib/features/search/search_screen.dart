import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import 'widgets/dish_results_list.dart';
import 'widgets/filters_sheet.dart';
import 'widgets/search_home_view.dart';
import 'widgets/search_loading_view.dart';
import 'widgets/search_map_view.dart';
import 'widgets/search_results_list.dart';
import 'widgets/search_utils.dart';

/// Internal view state for the "Buscar" tab (design-brief §0, §2.1-2.4): a
/// single screen whose body swaps between home/loading/list/map depending on
/// where the user is in the search flow — not separate routes, matching how
/// the Claude Design prototype models this tab as one `state.view`.
enum _SearchView { home, loading, list, map }

/// "Lugares"/"Platos" result mode (design-brief §2.9/backlog item 5 —
/// analogue of `web/components/features/buscar/ResultModeToggle.tsx`'s
/// `ResultMode`). Orthogonal to [_SearchView]: it only matters once results
/// are showing (`list`/`map`), and switching to [platos] forces the results
/// view back to `list` — there's no per-dish map pin, same as web (dishes
/// only ever render as a list/grid, never on `SearchResultsGrid`'s map
/// equivalent).
enum _ResultMode { lugares, platos }

/// Container for the "Buscar" tab. Owns the view-state machine, the current
/// query text, and navigation to the restaurant detail route; delegates
/// actual rendering to the view-specific widgets under `widgets/`.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initial, super.key});

  /// A result already resolved by the home hero's AI search (see
  /// `core/router/app_router.dart`'s `SearchScreen(initial: state.extra
  /// as SearchScreenInitial?)`), or `null` for a plain tab switch — in
  /// which case this screen shows its normal home/search-entry view exactly
  /// as before.
  final SearchScreenInitial? initial;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  /// Simulated network delay between submitting a search and seeing results.
  /// The design brief specifies 550ms (name search) / 950ms (AI search); we
  /// don't distinguish those two modes at this stage, so a single value in
  /// between is used instead.
  static const _searchDelay = Duration(milliseconds: 700);

  // Default landing state for the Buscar tab (fix, 2026-09-09): the AI
  // prompt/hero (`_SearchView.home` -> `SearchHomeView`) belongs only on
  // Home — `/buscar` itself is a real, query-less results list on web
  // (`web/app/buscar/page.tsx`), so tapping the tab must land straight on
  // the merchant list, not the hero. `_SearchView.home` is only ever
  // entered here as this initial value; nothing else in this class sets it
  // (see `_enterLoading`/`_toggleResultsMode`/`_setResultMode`), so it's
  // intentionally unreachable now rather than removed outright — no time to
  // rip out `SearchHomeView` wiring under today's deadline.
  _SearchView _view = _SearchView.list;
  _ResultMode _resultMode = _ResultMode.lugares;
  String _query = '';
  SearchFilters _filters = const SearchFilters();
  final TextEditingController _resultsSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    // Deferred to the post-frame callback: calling setState synchronously
    // inside initState (before the first build) throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyAiSearchResult(initial);
    });
  }

  @override
  void dispose() {
    _resultsSearchController.dispose();
    super.dispose();
  }

  void _startSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(analyticsServiceProvider).trackSearchSubmitted(trimmed);
    setState(() {
      _query = trimmed;
      _resultsSearchController.text = trimmed;
    });
    _enterLoading();
  }

  /// Same "loading -> list" transition as [_startSearch], but seeded from an
  /// already-resolved AI search result (home hero -> `POST /api/v1/search`
  /// -> `mapSearchQueryFiltersToInitial`, see `search_utils.dart`) instead
  /// of a plain typed query. Unlike [_startSearch], an empty [query] is
  /// valid here — Gemini may have fully covered the request via structured
  /// filters alone (e.g. "algo picante y barato en Palermo" has no leftover
  /// free-text fragment), so this must not bail out the way [_startSearch]'s
  /// empty-text guard does.
  void _applyAiSearchResult(SearchScreenInitial initial) {
    if (initial.query.isNotEmpty) {
      ref.read(analyticsServiceProvider).trackSearchSubmitted(initial.query);
    }
    setState(() {
      _query = initial.query;
      _resultsSearchController.text = initial.query;
      _filters = initial.filters;
      _resultMode = initial.startInPlatos
          ? _ResultMode.platos
          : _ResultMode.lugares;
    });
    _enterLoading();
  }

  void _enterLoading() {
    setState(() => _view = _SearchView.loading);
    Future.delayed(_searchDelay, () {
      // Guard against the user navigating away (or restarting a search)
      // while the simulated delay was still running.
      if (!mounted || _view != _SearchView.loading) return;
      setState(() => _view = _SearchView.list);
    });
  }

  void _updateQueryLive(String query) {
    setState(() => _query = query);
  }

  void _clearQuery() {
    _resultsSearchController.clear();
    setState(() => _query = '');
  }

  void _clearFilters() {
    setState(() => _filters = const SearchFilters());
  }

  void _toggleResultsMode() {
    setState(() {
      _view = _view == _SearchView.map ? _SearchView.list : _SearchView.map;
    });
  }

  void _setResultMode(_ResultMode mode) {
    if (mode == _resultMode) return;
    setState(() {
      _resultMode = mode;
      // Dishes have no map pins (see [_ResultMode]'s doc) — force back to
      // the list view when switching into "Platos" while the map was open.
      if (mode == _ResultMode.platos && _view == _SearchView.map) {
        _view = _SearchView.list;
      }
    });
  }

  void _openMerchant(int merchantId) {
    context.push(AppRoutes.merchantDetail(merchantId));
  }

  Future<void> _openFiltersSheet() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FiltersSheet(initialFilters: _filters),
    );
    // A `null` result means the sheet was dismissed without tapping
    // "Aplicar" (swipe down, scrim tap, close button) — keep the previous
    // filters in that case instead of clearing them.
    if (result == null || !mounted) return;
    setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    // Session gate (product-owner request, 2026-09-09): unlike web's
    // `/buscar` (deliberately public/anonymous, see backend commit
    // `4dddea0`), Flutter search+filters require a logged-in consumer — a
    // genuine, intentional cross-platform divergence for this MVP, not a
    // bug to reconcile with web later (see
    // `openspec/changes/fudo-consumers-mvp/learnings.md`). Reuses the exact
    // same mechanism/pattern as `features/gifting/gifting_screen.dart`'s
    // `_LoginRequiredCard`: watch [isLoggedInProvider], replace the gated
    // UI with a login prompt whose CTA goes to `AppRoutes.myPlaces` (the
    // screen with the embedded login form) instead of inventing a new gate.
    final isLoggedIn = ref.watch(isLoggedInProvider);
    if (!isLoggedIn) {
      return _SearchLoginRequiredView(
        onLoginTap: () => context.go(AppRoutes.myPlaces),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: switch (_view) {
          _SearchView.home => SearchHomeView(onSearch: _startSearch),
          _SearchView.loading => SearchLoadingView(query: _query),
          _SearchView.list => Stack(
            children: [
              Column(
                children: [
                  _ResultsHeader(
                    controller: _resultsSearchController,
                    onChanged: _updateQueryLive,
                    onClear: _clearQuery,
                    resultMode: _resultMode,
                    onResultModeChanged: _setResultMode,
                    showingMap: false,
                    activeFilterCount: _filters.activeCount,
                    onOpenFilters: _openFiltersSheet,
                  ),
                  Expanded(
                    child: switch (_resultMode) {
                      _ResultMode.platos => DishResultsList(
                        query: _query,
                        filters: _filters,
                        onClearSearch: _clearQuery,
                        onClearFilters: _clearFilters,
                        onOpenMerchant: _openMerchant,
                      ),
                      _ResultMode.lugares => SearchResultsList(
                        query: _query,
                        filters: _filters,
                        onClearSearch: _clearQuery,
                        onClearFilters: _clearFilters,
                        onOpenMerchant: _openMerchant,
                      ),
                    },
                  ),
                ],
              ),
              // Floating "Mapa" pill (design-brief parity with web's
              // `MapToggleSection.tsx` phone pill): dishes have no map pins
              // (see [_ResultMode]'s doc), so this only shows in "Lugares"
              // mode, same guard as the old inline toggle it replaces.
              // Positioned above the shell's floating bottom nav (
              // `main_shell.dart`'s `_FloatingBottomNav`, `extendBody: true`
              // there means this screen's own coordinate space already
              // extends behind it) instead of overlapping it.
              if (_resultMode == _ResultMode.lugares)
                Positioned(
                  right: 16,
                  bottom: 96,
                  child: _FloatingMapButton(onTap: _toggleResultsMode),
                ),
            ],
          ),
          // Full-height map (matches web's `966b371` fix): the map fills the
          // whole body edge-to-edge instead of sitting below the header in
          // normal Column flow, with the search bar / mode toggle floating
          // on top as an overlay. `_ResultsHeader` has no opaque wrapper of
          // its own — only its individual pills/fields (TextField, filters
          // button, mode toggles) paint a background — so it already reads
          // as a floating overlay with the map visible through the gaps,
          // same as the web overlay row; no extra scrim/blur needed.
          _SearchView.map => Stack(
            children: [
              Positioned.fill(
                child: SearchMapView(
                  query: _query,
                  onOpenMerchant: _openMerchant,
                  onBackToList: _toggleResultsMode,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ResultsHeader(
                  controller: _resultsSearchController,
                  onChanged: _updateQueryLive,
                  onClear: _clearQuery,
                  resultMode: _resultMode,
                  onResultModeChanged: _setResultMode,
                  showingMap: true,
                  activeFilterCount: _filters.activeCount,
                  onOpenFilters: _openFiltersSheet,
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// "Iniciá sesión para buscar" gate — shown instead of the whole search UI
/// while [isLoggedInProvider] is `false` (see the session-gate comment on
/// [_SearchScreenState.build]). Same visual language and CTA target
/// (`AppRoutes.myPlaces`, where the embedded login form lives) as
/// `features/gifting/gifting_screen.dart`'s `_LoginRequiredCard`; unlike
/// that one, this replaces the *entire* screen body instead of just a
/// section, because — unlike "Regalar" — there is no logged-out-friendly
/// content to keep showing on this tab (search+filters are fully gated per
/// the product owner's explicit request).
class _SearchLoginRequiredView extends StatelessWidget {
  const _SearchLoginRequiredView({required this.onLoginTap});

  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.32),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusHero),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.priceChipBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Symbols.lock,
                        color: AppTheme.accent,
                        size: 21,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Iniciá sesión para buscar',
                      style: AppTheme.title.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Para buscar restaurantes y platos, y usar los '
                      'filtros, necesitás una cuenta.',
                      style: AppTheme.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('searchLoginRequiredButton'),
                        onPressed: onLoginTap,
                        child: const Text('Iniciar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header shown above both the list and map results views (design-brief
/// §2.3): editable search text (so switching Lista/Mapa keeps the same query
/// and, if edited, both views re-filter against it) plus the Lista/Mapa
/// toggle.
class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.resultMode,
    required this.onResultModeChanged,
    required this.showingMap,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final _ResultMode resultMode;
  final ValueChanged<_ResultMode> onResultModeChanged;
  final bool showingMap;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: AppTheme.body,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, tipo o barrio',
                    prefixIcon: const Icon(
                      Symbols.search,
                      color: AppTheme.textTertiary,
                    ),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Symbols.close,
                              color: AppTheme.textTertiary,
                            ),
                            onPressed: onClear,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FiltersButton(
                activeCount: activeFilterCount,
                onTap: onOpenFilters,
              ),
            ],
          ),
          // Matches web's actual phone toolbar (`BuscarView.tsx`): the
          // Lugares/Platos toggle only shows in normal list mode — the map
          // overlay floats just the search bar + filter trigger on top of
          // the map (`mapOverlay` there is `<>{searchBar}</>`, no
          // `ResultModeToggle`). Previously this row also crammed in a
          // second Lista/Mapa pill (removed — see [_FloatingMapButton],
          // which now owns that job, same as web's `MapToggleSection`
          // floating pill), which is what caused the real "RIGHT OVERFLOWED
          // BY 26 PIXELS" render error on narrow phones: two full pill rows
          // sharing one `Row` with only a `Spacer` between them can still
          // overflow if their own intrinsic widths alone exceed the
          // available width, since `Spacer` only claims leftover space and
          // never shrinks its siblings.
          if (!showingMap) ...[
            const SizedBox(height: 12),
            _ResultModeToggle(mode: resultMode, onChanged: onResultModeChanged),
          ],
        ],
      ),
    );
  }
}

/// "Lugares"/"Platos" result-mode pill (design-brief §2.9/backlog item 5 —
/// analogue of `web/components/features/buscar/ResultModeToggle.tsx`).
class _ResultModeToggle extends StatelessWidget {
  const _ResultModeToggle({required this.mode, required this.onChanged});

  final _ResultMode mode;
  final ValueChanged<_ResultMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ResultModeButton(
            label: 'Lugares',
            icon: Symbols.storefront,
            selected: mode == _ResultMode.lugares,
            onTap: () => onChanged(_ResultMode.lugares),
          ),
          _ResultModeButton(
            label: 'Platos',
            icon: Symbols.restaurant_menu,
            selected: mode == _ResultMode.platos,
            onTap: () => onChanged(_ResultMode.platos),
          ),
        ],
      ),
    );
  }
}

class _ResultModeButton extends StatelessWidget {
  const _ResultModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.body.copyWith(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filters entry point (design-brief §2.3/§2.9): opens [FiltersSheet] and
/// shows a small badge with the current active-filter count.
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Symbols.tune, color: AppTheme.textSecondary),
              if (activeCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$activeCount',
                      textAlign: TextAlign.center,
                      style: AppTheme.body.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating "Mapa" pill shown over the results list (design-brief parity
/// with web's `MapToggleSection.tsx` phone pill, e.g. `bg-nav ... shadow-nav
/// backdrop-blur-md`): switches into the already-built [SearchMapView] map
/// mode. Web's own back-the-other-way control is a separate in-map button
/// (`format_list_bulleted` pill while the map is open) — this app's
/// equivalent is `SearchMapView`'s existing `search-map-back-to-list` FAB,
/// untouched here.
class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        side: const BorderSide(color: AppTheme.border),
      ),
      elevation: 8,
      shadowColor: AppTheme.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.map, size: 19, color: AppTheme.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Mapa',
                style: AppTheme.body.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
