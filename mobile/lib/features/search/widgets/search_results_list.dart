import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../../data/models/visit_summary.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/main_shell.dart';
import '../../../shared/widgets/network_error_view.dart';
import 'search_utils.dart';

/// Merchant id → visit count, built from `visitSummariesProvider(null)`.
/// Returns an empty map while that provider hasn't resolved yet, so
/// `applySearchFilters`' "hideVisited"/"mostVisited" behavior just has no
/// effect in that brief window instead of throwing.
Map<int, int> _visitCountsByMerchant(List<VisitSummary>? summaries) {
  if (summaries == null) return const {};
  return {for (final summary in summaries) summary.merchantId: summary.count};
}

/// Results list view for the "Buscar" tab (design-brief §2.3): merchant
/// cards filtered by [query], a result-count + sort row, and an empty
/// state.
///
/// Also owns the design's infinite-scroll reveal (parity with web's
/// `SearchResultsGrid.tsx` — same `PAGE_SIZE`/`LOAD_MORE_DELAY_MS`): the
/// full filtered list is already resolved client-side (via
/// `merchantsProvider` + `applySearchFilters`), so "loading more" here means
/// revealing more of an already-known array as the user nears the bottom,
/// not a new network fetch — see that file's own doc comment for the same
/// rationale. `ConsumerStatefulWidget` (rather than the previous
/// `ConsumerWidget`) so the revealed-count/scroll-controller state survives
/// rebuilds triggered by provider updates instead of resetting every frame.
class SearchResultsList extends ConsumerStatefulWidget {
  const SearchResultsList({
    required this.query,
    required this.onClearSearch,
    required this.onOpenMerchant,
    required this.onFiltersChanged,
    this.filters = const SearchFilters(),
    this.onClearFilters,
    super.key,
  });

  final String query;
  final SearchFilters filters;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onOpenMerchant;

  /// Applies an edited [SearchFilters] back up to the owning `SearchScreen`
  /// — today only used by the sort dropdown next to the result count
  /// (design parity with web's "N lugares encontrados · Relevancia ▾" row),
  /// the same [SearchFilters.copyWith]/[SortOption] vocabulary the advanced
  /// filters sheet's "Básico" category already wires up
  /// (`filters_sheet.dart`'s `_BasicoCategory`) — a second entry point into
  /// the same sort state, not a parallel one.
  final ValueChanged<SearchFilters> onFiltersChanged;

  /// Resets [filters] to the default (no filters). Only used by the empty
  /// state's "Limpiar filtros" action when filters (rather than the text
  /// query) are the reason the list is empty — `null` falls back to
  /// [onClearSearch] instead, e.g. when a caller doesn't own filter state.
  final VoidCallback? onClearFilters;

  @override
  ConsumerState<SearchResultsList> createState() => _SearchResultsListState();
}

class _SearchResultsListState extends ConsumerState<SearchResultsList> {
  /// Matches web's `PAGE_SIZE`/`LOAD_MORE_DELAY_MS`
  /// (`SearchResultsGrid.tsx`) exactly: same batch size, same simulated
  /// "loading more" delay before the next batch reveals.
  static const int _pageSize = 10;
  static const Duration _loadMoreDelay = Duration(milliseconds: 750);

  /// How close to the bottom (in logical pixels) triggers the next reveal —
  /// the Flutter analogue of web's `IntersectionObserver` sentinel with
  /// `rootMargin: "400px"`.
  static const double _loadMoreThreshold = 400;

  /// How many skeleton rows to show while the next page is "loading" —
  /// matches web's 3 `RowSkeleton` placeholders on phone.
  static const int _loadingSkeletonCount = 3;

  final ScrollController _scrollController = ScrollController();

  int _visibleCount = _pageSize;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _resetKey;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    Future.delayed(_loadMoreDelay, () {
      if (!mounted) return;
      setState(() {
        _visibleCount += _pageSize;
        _loadingMore = false;
      });
    });
  }

  /// A new search query or filter set means a different result set — the
  /// reveal window resets to the first page, same as web remounting
  /// `SearchResultsGrid` via a filter-params `key` on any filter change
  /// (see that file's own doc comment). Detected via a cheap identity-key
  /// comparison at the top of [build] instead of `didUpdateWidget`
  /// boilerplate — safe because it only mutates fields that are read later
  /// in the same build pass, no `setState` needed for the current frame.
  void _resetIfFiltersChanged() {
    final key = '${widget.query}|${widget.filters.hashCode}';
    if (_resetKey != null && _resetKey != key) {
      _visibleCount = _pageSize;
      _loadingMore = false;
    }
    _resetKey = key;
  }

  @override
  Widget build(BuildContext context) {
    _resetIfFiltersChanged();

    final merchantsAsync = ref.watch(merchantsProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);
    // All four default to an empty map while still loading —
    // `applySearchFilters` treats that as "no effect yet" for the filters
    // that need them (dieta, ocultar visitados, más visitados, abierto
    // ahora, premio disponible), rather than blocking the whole list on
    // extra fetches.
    final merchantTagIds = ref.watch(merchantTagIdsProvider).value ?? const {};
    final visitCountsByMerchant = _visitCountsByMerchant(
      ref.watch(visitSummariesProvider(null)).value,
    );
    final businessHoursByMerchant =
        ref.watch(businessHoursByMerchantProvider).value ?? const {};
    final loyaltyRulesByMerchant =
        ref.watch(loyaltyRulesByMerchantProvider).value ?? const {};

    return merchantsAsync.when(
      data: (merchants) {
        final filtered = applySearchFilters(
          filterMerchants(merchants, widget.query),
          widget.filters,
          merchantTagIds: merchantTagIds,
          visitCountsByMerchant: visitCountsByMerchant,
          businessHoursByMerchant: businessHoursByMerchant,
          loyaltyRulesByMerchant: loyaltyRulesByMerchant,
        );
        if (filtered.isEmpty) {
          _hasMore = false;
          return _EmptyResults(
            query: widget.query,
            hasActiveFilters: widget.filters.activeCount > 0,
            onClear: widget.filters.activeCount > 0
                ? (widget.onClearFilters ?? widget.onClearSearch)
                : widget.onClearSearch,
          );
        }

        final visible = _visibleCount.clamp(0, filtered.length);
        _hasMore = visible < filtered.length;
        final itemCount = visible + (_loadingMore ? _loadingSkeletonCount : 0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    filtered.length == 1
                        ? '1 coincidencia'
                        : '${filtered.length} coincidencias',
                    style: AppTheme.bodySecondary,
                  ),
                  _SortButton(
                    sort: widget.filters.sort,
                    onChanged: (option) => widget.onFiltersChanged(
                      widget.filters.copyWith(sort: option),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                // Bottom padding sized off the SAME shared nav metrics
                // `main_shell.dart`'s `_FloatingBottomNav` and this screen's
                // own `_FloatingMapButton` already use
                // (`mainShellNavBottomMargin`/`mainShellNavPillHeight`) —
                // not a guessed constant — plus a fixed 16px gap so the
                // last real card clears the floating pill visually. The
                // scrollable itself still reaches the TRUE bottom of the
                // viewport (no dead gap of bare background above the
                // floating pill): see `search_screen.dart`'s
                // `SafeArea(bottom: false)` fix for the other half of this.
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  mainShellNavBottomMargin(context) + mainShellNavPillHeight + 16,
                ),
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index >= visible) {
                    return const _ResultSkeletonCard();
                  }
                  final merchant = filtered[index];
                  return _MerchantCard(
                    merchant: merchant,
                    isFavorite: favoriteIds.contains(merchant.id),
                    onToggleFavorite: () => ref
                        .read(favoriteIdsProvider.notifier)
                        .toggle(merchant.id),
                    onTap: () => widget.onOpenMerchant(merchant.id),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (error, stackTrace) => NetworkErrorView(
        message: 'No pudimos cargar los lugares.',
        onRetry: () => ref.invalidate(merchantsProvider),
      ),
    );
  }
}

/// Sort trigger next to the result count — design parity with web's
/// "Relevancia ▾" (`SortMenu.tsx`): shows the current [SortOption.label]
/// and opens a menu to pick another.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final SortOption sort;
  final ValueChanged<SortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortOption>(
      initialValue: sort,
      onSelected: onChanged,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.border),
      ),
      itemBuilder: (context) => SortOption.values
          .map(
            (option) => PopupMenuItem<SortOption>(
              value: option,
              child: Text(
                option.label,
                style: AppTheme.body.copyWith(
                  fontWeight: option == sort ? FontWeight.w700 : FontWeight.w400,
                  color: option == sort ? AppTheme.accent : AppTheme.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sort.label,
            style: AppTheme.bodySecondary.copyWith(fontWeight: FontWeight.w600),
          ),
          const Icon(Symbols.expand_more, size: 18, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

/// Loading-more placeholder shown while the next page reveals (parity with
/// web's `RowSkeleton`) — mirrors [_MerchantCard]'s own shape/radii 1:1
/// (same `AspectRatio(16/9)` + `Material` surface) so nothing jumps size
/// once the real card replaces it, using the same shimmer-sweep technique
/// `search_loading_view.dart`'s `_ShimmerSkeleton` uses. Duplicated rather
/// than shared: that one is private to its own file, which is out of this
/// task's edit scope.
class _ResultSkeletonCard extends StatefulWidget {
  const _ResultSkeletonCard();

  @override
  State<_ResultSkeletonCard> createState() => _ResultSkeletonCardState();
}

class _ResultSkeletonCardState extends State<_ResultSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shimmerBox({
    double width = double.infinity,
    required double height,
    required double radius,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(1 + 3 * t, 0),
              colors: const [
                AppTheme.surfaceSecondary,
                AppTheme.border,
                AppTheme.surfaceSecondary,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _shimmerBox(height: double.infinity, radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: _shimmerBox(height: 16, radius: 6),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _shimmerBox(width: 46, height: 20, radius: AppTheme.radiusPill),
                    const SizedBox(width: 8),
                    _shimmerBox(width: 60, height: 12, radius: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({
    required this.merchant,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Merchant merchant;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typePresentation = merchant.type;
    final priceLabel = formatPriceRange(merchant);
    final distanceLabel = formatDistance(distanceKmFromUser(merchant));

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CoverImage(
                    imageUrl: merchant.coverImageUrl,
                    typeColor: typePresentation.color,
                    typeIcon: typePresentation.icon,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _CategoryBadge(type: merchant.type),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _FavoriteButton(
                      isFavorite: isFavorite,
                      onTap: onToggleFavorite,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: AppTheme.title.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (priceLabel != null) ...[
                        _PriceChip(label: priceLabel),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        Symbols.near_me,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(distanceLabel, style: AppTheme.bodySecondary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.imageUrl,
    required this.typeColor,
    required this.typeIcon,
  });

  final String? imageUrl;
  final Color typeColor;
  final IconData typeIcon;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return _placeholder();
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder();
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: typeColor.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Icon(typeIcon, color: typeColor, size: 32),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.type});

  final MerchantType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
      child: Icon(type.icon, color: Colors.white, size: 16),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFavorite ? Symbols.favorite : Symbols.favorite_border,
            color: isFavorite ? AppTheme.accent : Colors.white,
            size: 18,
            fill: isFavorite ? 1 : 0,
          ),
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.priceChipBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: AppTheme.body.copyWith(
          color: AppTheme.priceChipText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.query,
    required this.onClear,
    this.hasActiveFilters = false,
  });

  final String query;
  final VoidCallback onClear;

  /// When the empty result is caused by the advanced filters (design-brief
  /// §2.3) rather than the text query, show "Ningún lugar con esos
  /// filtros"/"Limpiar filtros" instead of the text-search copy.
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.search_off,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'Ningún lugar con esos filtros'
                  : 'Sin resultados para "$query"',
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onClear,
              child: Text(
                hasActiveFilters ? 'Limpiar filtros' : 'Limpiar búsqueda',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
