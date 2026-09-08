import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../../data/models/visit_summary.dart';
import '../../../data/providers.dart';
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
/// cards filtered by [query], result-count copy, and an empty state.
class SearchResultsList extends ConsumerWidget {
  const SearchResultsList({
    required this.query,
    required this.onClearSearch,
    required this.onOpenMerchant,
    this.filters = const SearchFilters(),
    this.onClearFilters,
    super.key,
  });

  final String query;
  final SearchFilters filters;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onOpenMerchant;

  /// Resets [filters] to the default (no filters). Only used by the empty
  /// state's "Limpiar filtros" action when filters (rather than the text
  /// query) are the reason the list is empty — `null` falls back to
  /// [onClearSearch] instead, e.g. when a caller doesn't own filter state.
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantsProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);
    // Both default to an empty map while still loading — `applySearchFilters`
    // treats that as "no effect yet" for the filters that need them (dieta,
    // ocultar visitados, más visitados), rather than blocking the whole list
    // on two extra fetches.
    final merchantTagIds = ref.watch(merchantTagIdsProvider).value ?? const {};
    final visitCountsByMerchant = _visitCountsByMerchant(
      ref.watch(visitSummariesProvider(null)).value,
    );

    return merchantsAsync.when(
      data: (merchants) {
        final filtered = applySearchFilters(
          filterMerchants(merchants, query),
          filters,
          merchantTagIds: merchantTagIds,
          visitCountsByMerchant: visitCountsByMerchant,
        );
        if (filtered.isEmpty) {
          return _EmptyResults(
            query: query,
            hasActiveFilters: filters.activeCount > 0,
            onClear: filters.activeCount > 0
                ? (onClearFilters ?? onClearSearch)
                : onClearSearch,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                filtered.length == 1
                    ? '1 coincidencia'
                    : '${filtered.length} coincidencias',
                style: AppTheme.bodySecondary,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final merchant = filtered[index];
                  return _MerchantCard(
                    merchant: merchant,
                    isFavorite: favoriteIds.contains(merchant.id),
                    onToggleFavorite: () => ref
                        .read(favoriteIdsProvider.notifier)
                        .toggle(merchant.id),
                    onTap: () => onOpenMerchant(merchant.id),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (error, stackTrace) => Center(
        child: Text(
          'No pudimos cargar los lugares.',
          style: AppTheme.bodySecondary,
        ),
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
