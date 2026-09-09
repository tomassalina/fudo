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
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  /// Simulated network delay between submitting a search and seeing results.
  /// The design brief specifies 550ms (name search) / 950ms (AI search); we
  /// don't distinguish those two modes at this stage, so a single value in
  /// between is used instead.
  static const _searchDelay = Duration(milliseconds: 700);

  _SearchView _view = _SearchView.home;
  _ResultMode _resultMode = _ResultMode.lugares;
  String _query = '';
  SearchFilters _filters = const SearchFilters();
  final TextEditingController _resultsSearchController =
      TextEditingController();

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
      _view = _SearchView.loading;
    });
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: switch (_view) {
          _SearchView.home => SearchHomeView(onSearch: _startSearch),
          _SearchView.loading => SearchLoadingView(query: _query),
          _SearchView.list || _SearchView.map => Column(
            children: [
              _ResultsHeader(
                controller: _resultsSearchController,
                onChanged: _updateQueryLive,
                onClear: _clearQuery,
                resultMode: _resultMode,
                onResultModeChanged: _setResultMode,
                showingMap: _view == _SearchView.map,
                onToggleMode: _toggleResultsMode,
                activeFilterCount: _filters.activeCount,
                onOpenFilters: _openFiltersSheet,
              ),
              Expanded(
                child: switch ((_resultMode, _view)) {
                  (_ResultMode.platos, _) => DishResultsList(
                    query: _query,
                    filters: _filters,
                    onClearSearch: _clearQuery,
                    onClearFilters: _clearFilters,
                    onOpenMerchant: _openMerchant,
                  ),
                  (_ResultMode.lugares, _SearchView.map) => SearchMapView(
                    query: _query,
                    onOpenMerchant: _openMerchant,
                    onBackToList: _toggleResultsMode,
                  ),
                  (_ResultMode.lugares, _) => SearchResultsList(
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
        },
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
    required this.onToggleMode,
    required this.activeFilterCount,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final _ResultMode resultMode;
  final ValueChanged<_ResultMode> onResultModeChanged;
  final bool showingMap;
  final VoidCallback onToggleMode;
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
          const SizedBox(height: 12),
          Row(
            children: [
              _ResultModeToggle(
                mode: resultMode,
                onChanged: onResultModeChanged,
              ),
              const Spacer(),
              // Dishes have no map view (see [_ResultMode]'s doc) — the
              // Lista/Mapa toggle only makes sense in "Lugares" mode.
              if (resultMode == _ResultMode.lugares)
                _ModeToggle(showingMap: showingMap, onToggle: onToggleMode),
            ],
          ),
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

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.showingMap, required this.onToggle});

  final bool showingMap;
  final VoidCallback onToggle;

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
          _ModeButton(
            label: 'Lista',
            icon: Symbols.view_list,
            selected: !showingMap,
            onTap: showingMap ? onToggle : null,
          ),
          _ModeButton(
            label: 'Mapa',
            icon: Symbols.map,
            selected: showingMap,
            onTap: showingMap ? null : onToggle,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
