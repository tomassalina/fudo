import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/search_home_view.dart';
import 'widgets/search_loading_view.dart';
import 'widgets/search_map_view.dart';
import 'widgets/search_results_list.dart';

/// Internal view state for the "Buscar" tab (design-brief §0, §2.1-2.4): a
/// single screen whose body swaps between home/loading/list/map depending on
/// where the user is in the search flow — not separate routes, matching how
/// the Claude Design prototype models this tab as one `state.view`.
enum _SearchView { home, loading, list, map }

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
  String _query = '';
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

  void _toggleResultsMode() {
    setState(() {
      _view = _view == _SearchView.map ? _SearchView.list : _SearchView.map;
    });
  }

  void _openMerchant(int merchantId) {
    context.push(AppRoutes.merchantDetail(merchantId));
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
                showingMap: _view == _SearchView.map,
                onToggleMode: _toggleResultsMode,
              ),
              Expanded(
                child: _view == _SearchView.map
                    ? SearchMapView(
                        query: _query,
                        onOpenMerchant: _openMerchant,
                        onBackToList: _toggleResultsMode,
                      )
                    : SearchResultsList(
                        query: _query,
                        onClearSearch: _clearQuery,
                        onOpenMerchant: _openMerchant,
                      ),
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
    required this.showingMap,
    required this.onToggleMode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showingMap;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _ModeToggle(showingMap: showingMap, onToggle: onToggleMode),
          ),
        ],
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
