import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/merchant.dart';
import '../../../data/models/visit_summary.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/network_error_view.dart';
import 'search_utils.dart';

/// A menu item plus the merchant that serves it — the "Platos" result-mode
/// analogue of `web/lib/types`' `DishSearchResult`, built here instead of as
/// a shared domain model since it only exists for this one screen.
@immutable
class DishSearchResult {
  const DishSearchResult({required this.item, required this.merchant});

  final MenuItem item;
  final Merchant merchant;
}

Map<int, int> _visitCountsByMerchant(List<VisitSummary>? summaries) {
  if (summaries == null) return const {};
  return {for (final summary in summaries) summary.merchantId: summary.count};
}

/// Cross-merchant dish search (design brief §2.9/backlog item 5, `Buscar`
/// tab's "Platos" result mode — analogue of
/// `web/components/features/buscar/DishCard.tsx` +
/// `SearchResultsGrid.tsx`/`getDishSearchResults` in
/// `web/lib/data/menu-items.ts`).
///
/// [filters] narrows the *candidate merchants* the same way
/// [SearchResultsList] does (type, barrio, distancia, precio, dieta,
/// ocultar visitados, orden) via [applySearchFilters] — but, unlike that
/// widget, [query] is matched against each *dish*'s own name/description/
/// section (plus its merchant's name), not the merchant's fields, since
/// that's what "Platos" mode is for. Only [MenuItem.active] items are shown,
/// same rule `restaurant_detail_screen.dart`'s menu tab uses.
class DishResultsList extends ConsumerWidget {
  const DishResultsList({
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
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantsProvider);
    final menuItemsAsync = ref.watch(allMenuItemsProvider);
    final merchantTagIds = ref.watch(merchantTagIdsProvider).value ?? const {};
    final visitCountsByMerchant = _visitCountsByMerchant(
      ref.watch(visitSummariesProvider(null)).value,
    );

    if (merchantsAsync.hasError || menuItemsAsync.hasError) {
      return NetworkErrorView(
        message: 'No pudimos cargar los platos.',
        onRetry: () {
          ref.invalidate(merchantsProvider);
          ref.invalidate(allMenuItemsProvider);
        },
      );
    }

    final merchants = merchantsAsync.value;
    final menuItems = menuItemsAsync.value;
    if (merchants == null || menuItems == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    // Filters narrow the *candidate merchants* (same categories as the
    // merchant-search list), not the text query — that's applied to each
    // dish individually below.
    final candidateMerchants = applySearchFilters(
      merchants,
      filters,
      merchantTagIds: merchantTagIds,
      visitCountsByMerchant: visitCountsByMerchant,
    );
    final merchantsById = {for (final m in candidateMerchants) m.id: m};

    final normalizedQuery = normalizeForSearch(query.trim());
    final results = <DishSearchResult>[];
    for (final item in menuItems) {
      if (!item.active) continue;
      final merchant = merchantsById[item.merchantId];
      if (merchant == null) continue;
      if (normalizedQuery.isNotEmpty) {
        final haystack = normalizeForSearch(
          [
            item.name,
            item.description ?? '',
            item.section ?? '',
            merchant.name,
          ].join(' '),
        );
        if (!haystack.contains(normalizedQuery)) continue;
      }
      results.add(DishSearchResult(item: item, merchant: merchant));
    }

    if (results.isEmpty) {
      return _EmptyDishResults(
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
            results.length == 1
                ? '1 plato encontrado'
                : '${results.length} platos encontrados',
            style: AppTheme.bodySecondary,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final result = results[index];
              return _DishCard(
                result: result,
                onTap: () => onOpenMerchant(result.merchant.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.result, required this.onTap});

  final DishSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final merchant = result.merchant;
    final distanceLabel = formatDistance(distanceKmFromUser(merchant));

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DishImage(imageUrl: item.imageUrl, typeColor: merchant.type.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTheme.title.copyWith(fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PriceChip(label: formatMoney(item.price)),
                      ],
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: AppTheme.bodySecondary.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.name,
                            style: AppTheme.body.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _DishImage extends StatelessWidget {
  const _DishImage({required this.imageUrl, required this.typeColor});

  final String? imageUrl;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: imageUrl == null
          ? _placeholder()
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _placeholder();
              },
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: typeColor.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Icon(Symbols.restaurant_menu, color: typeColor, size: 28),
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

class _EmptyDishResults extends StatelessWidget {
  const _EmptyDishResults({
    required this.query,
    required this.onClear,
    this.hasActiveFilters = false,
  });

  final String query;
  final VoidCallback onClear;
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
              Symbols.restaurant_menu,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'Ningún plato con esos filtros'
                  : 'Sin platos para "$query"',
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
