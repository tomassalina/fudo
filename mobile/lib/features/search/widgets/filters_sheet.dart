import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../../data/models/tag.dart';
import '../../../data/providers.dart';
import 'search_utils.dart';

/// Advanced filters bottom sheet (design brief §2.9). Shown via
/// `showModalBottomSheet` (with a `SearchFilters` type argument) and
/// `builder: (_) => FiltersSheet(initialFilters: current)`: pops with the
/// edited [SearchFilters] when "Aplicar" is tapped, or with `null` if the sheet is
/// dismissed any other way (swipe down, tapping the scrim, the close
/// button) — callers should only replace their current filters when the
/// result is non-null.
///
/// Categories match the brief: Básico (orden/tipo/abierto ahora), Precio
/// (rango + dieta), Platos (simplified — see [_PlatosCategory] doc),
/// Ubicación (barrio/distancia) and Premios (premio de fidelización
/// disponible). "Ocultar visitados" sits outside the categories, same as in
/// the design.
class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({required this.initialFilters, super.key});

  final SearchFilters initialFilters;

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

enum _FilterCategory { basico, precio, platos, ubicacion, premios }

extension on _FilterCategory {
  String get label => switch (this) {
    _FilterCategory.basico => 'Básico',
    _FilterCategory.precio => 'Precio',
    _FilterCategory.platos => 'Platos',
    _FilterCategory.ubicacion => 'Ubicación',
    _FilterCategory.premios => 'Premios',
  };

  /// Per-category icon shown above the label on each tab pill — mirrors
  /// `FILTER_CATEGORIES` in web's `filter-rows.ts` (`tune`/`payments`/
  /// `restaurant_menu`/`location_on`/`redeem`).
  IconData get icon => switch (this) {
    _FilterCategory.basico => Symbols.tune,
    _FilterCategory.precio => Symbols.payments,
    _FilterCategory.platos => Symbols.restaurant_menu,
    _FilterCategory.ubicacion => Symbols.location_on,
    _FilterCategory.premios => Symbols.redeem,
  };
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late SearchFilters _draft;
  _FilterCategory _category = _FilterCategory.basico;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  void _update(SearchFilters next) => setState(() => _draft = next);

  void _clear() => setState(() => _draft = const SearchFilters());

  void _apply() => Navigator.of(context).pop(_draft);

  /// Per-category active-filter count for the tab badges — mirrors web's
  /// `countActiveFiltersByCategory` (`filter-rows.ts`), counting how many
  /// independent filtering decisions are active within each category (a
  /// multi-select row like diet tags still counts once, same as
  /// `SearchFilters.activeCount`'s own doc comment). "Platos" has no
  /// filterable state in this sheet (see [_PlatosCategory]'s doc), so it's
  /// always 0. "Ocultar visitados" sits outside every category (its own row
  /// below the tabs), so it's intentionally excluded here too.
  Map<_FilterCategory, int> get _categoryCounts {
    final filters = _draft;
    return {
      _FilterCategory.basico:
          (filters.sort != SortOption.relevance ? 1 : 0) +
          (filters.merchantType != null ? 1 : 0) +
          (filters.openNowOnly ? 1 : 0),
      _FilterCategory.precio:
          (filters.minPricePerPerson != null ||
                  filters.maxPricePerPerson != null
              ? 1
              : 0) +
          (filters.dietTagIds.isNotEmpty ? 1 : 0),
      _FilterCategory.platos: 0,
      _FilterCategory.ubicacion:
          (filters.neighborhood != null ? 1 : 0) +
          (filters.maxDistanceKm != null ? 1 : 0),
      _FilterCategory.premios: filters.rewardAvailableOnly ? 1 : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusBottomSheetTop),
          topRight: Radius.circular(AppTheme.radiusBottomSheetTop),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: mediaQuery.size.height * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text('Filtros', style: AppTheme.title)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Symbols.close,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    _ActiveCountPill(activeCount: _draft.activeCount),
                    const SizedBox(width: 8),
                    _HideVisitedPill(filters: _draft, onChanged: _update),
                  ],
                ),
              ),
              _CategoryTabs(
                selected: _category,
                onSelect: (category) => setState(() => _category = category),
                counts: _categoryCounts,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: switch (_category) {
                    _FilterCategory.basico => _BasicoCategory(
                      filters: _draft,
                      onChanged: _update,
                    ),
                    _FilterCategory.precio => _PrecioCategory(
                      filters: _draft,
                      onChanged: _update,
                    ),
                    _FilterCategory.platos => const _PlatosCategory(),
                    _FilterCategory.ubicacion => _UbicacionCategory(
                      filters: _draft,
                      onChanged: _update,
                    ),
                    _FilterCategory.premios => _PremiosCategory(
                      filters: _draft,
                      onChanged: _update,
                    ),
                  },
                ),
              ),
              const Divider(height: 1),
              _BottomActions(onClear: _clear, onApply: _apply),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category pill row — mirrors web's `FilterCategoryTabs.tsx` "sheet"
/// variant: a horizontally-scrollable row of fixed-width (78px), icon-
/// above-label pills (not `FilterSidebar`'s 2-column icon-then-label grid,
/// which this phone sheet has no use for). The active pill uses the same
/// accent-gradient/shadow convention as the app's other gradient pills
/// (e.g. the nav's gradient pill, commit `6857654`) instead of a flat
/// `ChoiceChip` fill, and carries a small numeral badge overlapping its
/// top-right corner for that category's active-filter count.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.selected,
    required this.onSelect,
    required this.counts,
  });

  final _FilterCategory selected;
  final ValueChanged<_FilterCategory> onSelect;

  /// Active-filter count per category, shown as a small numeral badge
  /// overlapping the tab's top-right corner (omitted when 0) — see
  /// `_FiltersSheetState._categoryCounts`.
  final Map<_FilterCategory, int> counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _FilterCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _FilterCategory.values[index];
          final isSelected = category == selected;
          final count = counts[category] ?? 0;
          return _CategoryTab(
            category: category,
            isSelected: isSelected,
            count: count,
            onTap: () => onSelect(category),
          );
        },
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  final _FilterCategory category;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.ctaGradient : null,
                  color: isSelected ? null : AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : AppTheme.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon,
                      size: 19,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.label,
                      style: AppTheme.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              top: -6,
              right: -6,
              child: _CategoryCountBadge(isSelected: isSelected, count: count),
            ),
        ],
      ),
    );
  }
}

/// Small rounded-full numeral badge for a category tab's active-filter
/// count — same accent-background/white-text convention as the design's
/// other small count badges, distinct from the bigger "N filtros activos"
/// pill in [_ActiveCountPill]. Mirrors web's `FilterCategoryTabs.tsx`
/// **sheet** variant specifically (`isActive ? "bg-white text-accent" :
/// "bg-accent text-white"`) — solid white/accent-text on the selected
/// tab, not the sidebar variant's translucent `white/25` treatment (that
/// variant is for `FilterSidebar`'s wide-layout grid, which this phone
/// sheet doesn't use).
class _CategoryCountBadge extends StatelessWidget {
  const _CategoryCountBadge({required this.isSelected, required this.count});

  final bool isSelected;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : AppTheme.accent,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        '$count',
        style: AppTheme.body.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isSelected ? AppTheme.accent : Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTheme.body.copyWith(
          color: AppTheme.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// "Básico": sort order, merchant type, and "Abierto ahora".
class _BasicoCategory extends StatelessWidget {
  const _BasicoCategory({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('ORDENAR POR'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SortOption.values.map((option) {
            final isSelected = filters.sort == option;
            return _FilterChoiceChip(
              label: option.label,
              selected: isSelected,
              onTap: () => onChanged(filters.copyWith(sort: option)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('TIPO DE LOCAL'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MerchantType.values.map((type) {
            final isSelected = filters.merchantType == type;
            return _FilterChoiceChip(
              label: merchantTypeLabel(type),
              icon: type.icon,
              selected: isSelected,
              onTap: () => onChanged(
                filters.copyWith(
                  merchantType: () => isSelected ? null : type,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _ToggleRow(
          label: 'Abierto ahora',
          value: filters.openNowOnly,
          onChanged: (value) =>
              onChanged(filters.copyWith(openNowOnly: value)),
        ),
      ],
    );
  }
}

/// "Precio": price-per-person range and diet tags.
class _PrecioCategory extends ConsumerWidget {
  const _PrecioCategory({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantsProvider);
    final tagsAsync = ref.watch(tagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('RANGO DE PRECIO POR PERSONA'),
        merchantsAsync.when(
          data: (merchants) => _PriceRangeSlider(
            merchants: merchants,
            filters: filters,
            onChanged: onChanged,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          ),
          error: (error, stackTrace) => Text(
            'No pudimos cargar los precios.',
            style: AppTheme.bodySecondary,
          ),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('DIETA'),
        tagsAsync.when(
          data: (tags) => _DietTagChips(
            tags: tags,
            filters: filters,
            onChanged: onChanged,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          ),
          error: (error, stackTrace) => Text(
            'No pudimos cargar las etiquetas de dieta.',
            style: AppTheme.bodySecondary,
          ),
        ),
      ],
    );
  }
}

class _PriceRangeSlider extends StatelessWidget {
  const _PriceRangeSlider({
    required this.merchants,
    required this.filters,
    required this.onChanged,
  });

  final List<Merchant> merchants;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final mins = merchants
        .map((m) => m.pricePerPersonMin)
        .whereType<double>();
    final maxs = merchants
        .map((m) => m.pricePerPersonMax)
        .whereType<double>();
    // Fallback bounds if no merchant has price data at all — keeps the
    // slider usable instead of crashing on an empty Iterable.
    final boundsMin = mins.isEmpty
        ? 0.0
        : mins.reduce((a, b) => a < b ? a : b);
    final boundsMax = maxs.isEmpty
        ? 100000.0
        : maxs.reduce((a, b) => a > b ? a : b);

    final currentMin = filters.minPricePerPerson ?? boundsMin;
    final currentMax = filters.maxPricePerPerson ?? boundsMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RangeSlider(
          values: RangeValues(
            currentMin.clamp(boundsMin, boundsMax),
            currentMax.clamp(boundsMin, boundsMax),
          ),
          min: boundsMin,
          max: boundsMax,
          activeColor: AppTheme.accent,
          inactiveColor: AppTheme.surfaceSecondary,
          onChanged: boundsMin >= boundsMax
              ? null
              : (values) => onChanged(
                  filters.copyWith(
                    minPricePerPerson: values.start,
                    maxPricePerPerson: values.end,
                  ),
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatMoney(currentMin), style: AppTheme.bodySecondary),
            Text(formatMoney(currentMax), style: AppTheme.bodySecondary),
          ],
        ),
      ],
    );
  }
}

/// The 5 real diet tags a merchant can carry (`backend/db/seeds.rb`:
/// `sin_tacc vegano vegetariano picante economico`), in display order —
/// mirrors `DIET_TAG_KEYS` in the web app's `filter-rows.ts`. `tagsProvider`'s
/// full tag catalog also carries unrelated values like
/// "para_llevar"/"con_delivery", so consumers filter down to just these
/// instead of rendering every known tag as a "diet" option.
///
/// Module-level (not private to [_DietTagChips]) so the Buscar top-section
/// AI chip row (`search_screen.dart`'s `_DietChipsRow`, design parity with
/// web's `AiChips.tsx`) can reuse the exact same 5 tags/order instead of
/// hand-rolling a second list that could drift out of sync with this one.
const List<String> dietTagOrder = [
  'vegano',
  'sin_tacc',
  'picante',
  'economico',
  'vegetariano',
];

/// Spanish display labels for [dietTagOrder], matching web's `TAG_LABELS`
/// (`web/lib/mock/merchants.ts`) — the catalog stores tag names as raw
/// snake_case identifiers, not display-ready text. See [dietTagOrder]'s doc
/// comment for why this is module-level rather than a private class member.
const Map<String, String> dietTagLabels = {
  'vegano': 'Vegano',
  'sin_tacc': 'Sin TACC',
  'picante': 'Picante',
  'economico': 'Económico',
  'vegetariano': 'Vegetariano',
};

class _DietTagChips extends StatelessWidget {
  const _DietTagChips({
    required this.tags,
    required this.filters,
    required this.onChanged,
  });

  final List<Tag> tags;
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final byName = {for (final tag in tags) tag.name: tag};
    final dietTags = [
      for (final name in dietTagOrder)
        if (byName[name] != null) byName[name]!,
    ];
    if (dietTags.isEmpty) {
      return Text(
        'No hay etiquetas de dieta cargadas todavía.',
        style: AppTheme.bodySecondary,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: dietTags.map((tag) {
        final isSelected = filters.dietTagIds.contains(tag.id);
        return _FilterChoiceChip(
          label: dietTagLabels[tag.name] ?? tag.name,
          selected: isSelected,
          onTap: () {
            final next = {...filters.dietTagIds};
            if (isSelected) {
              next.remove(tag.id);
            } else {
              next.add(tag.id);
            }
            onChanged(filters.copyWith(dietTagIds: next));
          },
        );
      }).toList(),
    );
  }
}

/// "Platos": intentionally simplified.
///
/// The design brief's "Platos" category (§2.9) covers price-per-dish,
/// menu section and "apto para" — all of which describe individual menu
/// items, not merchants. `search_results_list.dart` only renders a
/// cross-merchant *merchant* list today (backlog item 5, the cross-merchant
/// *dish* view, doesn't exist yet) — so there is nothing in this sheet's
/// result set for a dish-level filter to narrow. Rather than invent a
/// feature this app doesn't have, this category is a placeholder that
/// points at where the real filter will live once that view exists.
class _PlatosCategory extends StatelessWidget {
  const _PlatosCategory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            Symbols.restaurant_menu,
            color: AppTheme.textTertiary,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Filtro de platos disponible desde la vista de platos',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "Ubicación": neighborhood and max distance.
class _UbicacionCategory extends ConsumerWidget {
  const _UbicacionCategory({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  static const double _maxDistanceKm = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('BARRIO'),
        merchantsAsync.when(
          data: (merchants) {
            final neighborhoods =
                merchants
                    .map((m) => m.neighborhood)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort();
            if (neighborhoods.isEmpty) {
              return Text(
                'No hay barrios cargados todavía.',
                style: AppTheme.bodySecondary,
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: neighborhoods.map((neighborhood) {
                final isSelected = filters.neighborhood == neighborhood;
                return _FilterChoiceChip(
                  label: neighborhood,
                  selected: isSelected,
                  onTap: () => onChanged(
                    filters.copyWith(
                      neighborhood: () =>
                          isSelected ? null : neighborhood,
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          ),
          error: (error, stackTrace) => Text(
            'No pudimos cargar los barrios.',
            style: AppTheme.bodySecondary,
          ),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('DISTANCIA MÁXIMA'),
        Slider(
          value: (filters.maxDistanceKm ?? _maxDistanceKm).clamp(
            0.5,
            _maxDistanceKm,
          ),
          min: 0.5,
          max: _maxDistanceKm,
          divisions: 39,
          activeColor: AppTheme.accent,
          inactiveColor: AppTheme.surfaceSecondary,
          label: formatDistance(filters.maxDistanceKm ?? _maxDistanceKm),
          onChanged: (value) =>
              onChanged(filters.copyWith(maxDistanceKm: value)),
        ),
        Text(
          filters.maxDistanceKm == null
              ? 'Sin límite (hasta $_maxDistanceKm km)'
              : 'Hasta ${formatDistance(filters.maxDistanceKm!)}',
          style: AppTheme.bodySecondary,
        ),
      ],
    );
  }
}

/// "Premios": "does this merchant currently have an earned loyalty reward"
/// — see `search_utils.dart`'s `hasAvailableReward` doc for what "available"
/// means (the app has no "claimed" concept for loyalty rewards).
class _PremiosCategory extends StatelessWidget {
  const _PremiosCategory({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          label: 'Solo con premio de fidelización disponible',
          value: filters.rewardAvailableOnly,
          onChanged: (value) =>
              onChanged(filters.copyWith(rewardAvailableOnly: value)),
        ),
      ],
    );
  }
}

/// Active-filter-count pill shown in the header row, next to
/// [_HideVisitedPill] — mirrors web's `PhoneFilterSheet.tsx` `headerExtra`
/// count `<span>`: accent-gradient fill once at least one filter is active,
/// neutral surface/border otherwise. Always renders the count (including
/// "0 filtros activos"), matching web exactly — unlike the old bottom-of-
/// sheet text this replaces, which special-cased 0 as "Sin filtros activos".
class _ActiveCountPill extends StatelessWidget {
  const _ActiveCountPill({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final isActive = activeCount > 0;
    final label = activeCount == 1
        ? '1 filtro activo'
        : '$activeCount filtros activos';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: isActive ? AppTheme.ctaGradient : null,
        color: isActive ? null : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: isActive ? Colors.transparent : AppTheme.border,
        ),
      ),
      child: Text(
        label,
        style: AppTheme.body.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.white : AppTheme.textTertiary,
        ),
      ),
    );
  }
}

/// "Ocultar visitados" toggle pill shown in the header row, next to
/// [_ActiveCountPill] — mirrors web's `PhoneFilterSheet.tsx` `headerExtra`
/// toggle button (icon + label, `accent-soft`/`accent-light` tint when
/// active) rather than a `Switch` row between the body and footer, which is
/// where this control used to live.
class _HideVisitedPill extends StatelessWidget {
  const _HideVisitedPill({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = filters.hideVisited;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: () => onChanged(filters.copyWith(hideVisited: !isActive)),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.priceChipBackground : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: isActive
                  ? AppTheme.accent.withValues(alpha: 0.4)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.visibility_off,
                size: 17,
                color: isActive ? AppTheme.priceChipText : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Ocultar visitados',
                style: AppTheme.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppTheme.priceChipText
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.body)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.accent,
      labelStyle: AppTheme.body.copyWith(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontSize: 13,
      ),
      side: BorderSide(color: selected ? Colors.transparent : AppTheme.border),
    );
  }
}

/// Pinned footer: "Limpiar" (secondary, narrower) + "Aplicar" (primary,
/// wider) side by side — mirrors web's `PhoneFilterSheet.tsx` footer
/// (`flex-1` / `flex-[1.4]`). The active-filter count now lives in
/// [_ActiveCountPill] in the header instead of as text here.
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onClear, required this.onApply});

  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: OutlinedButton(
              onPressed: onClear,
              child: const Text('Limpiar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 7, child: _ApplyButton(onTap: onApply)),
        ],
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            'Aplicar',
            style: AppTheme.button.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
