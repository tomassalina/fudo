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
/// Ubicación (barrio/distancia) and Premios (simplified — see
/// [_PremiosCategory] doc). "Ocultar visitados" sits outside the categories,
/// same as in the design.
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
                    Expanded(
                      child: Text('Filtros avanzados', style: AppTheme.title),
                    ),
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
              const SizedBox(height: 8),
              _CategoryTabs(
                selected: _category,
                onSelect: (category) => setState(() => _category = category),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: _HideVisitedToggle(filters: _draft, onChanged: _update),
              ),
              _BottomActions(
                activeCount: _draft.activeCount,
                onClear: _clear,
                onApply: _apply,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelect});

  final _FilterCategory selected;
  final ValueChanged<_FilterCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _FilterCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _FilterCategory.values[index];
          final isSelected = category == selected;
          return ChoiceChip(
            label: Text(category.label),
            selected: isSelected,
            onSelected: (_) => onSelect(category),
            selectedColor: AppTheme.accent,
            labelStyle: AppTheme.body.copyWith(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: isSelected ? Colors.transparent : AppTheme.border,
            ),
          );
        },
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
///
/// [SearchFilters.openNowOnly] is rendered as a real toggle here (matching
/// the design) but is NOT applied by `applySearchFilters` — see
/// [SearchFilters]'s class doc.
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
          enabled: false,
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
    if (tags.isEmpty) {
      return Text(
        'No hay etiquetas de dieta cargadas todavía.',
        style: AppTheme.bodySecondary,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final isSelected = filters.dietTagIds.contains(tag.id);
        return _FilterChoiceChip(
          label: tag.name,
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

/// "Premios": intentionally simplified.
///
/// Checking "does this merchant currently have an unclaimed loyalty reward
/// available" requires cross-referencing `loyalty_rules` +
/// `visit_summaries` *per merchant* — both are exposed by [DataSource] only
/// scoped to a single merchant id (`loyaltyRulesProvider`/
/// `visitSummariesProvider(merchantId)`), because that's what the detail
/// screen's loyalty timeline needs. Computing it for every merchant in the
/// search results from this sheet would mean fetching both fixtures for
/// each of them on every filter change. So [SearchFilters.rewardAvailableOnly]
/// is a real toggle the user can set, but `applySearchFilters` does not act
/// on it yet — a future bulk data-source method
/// (mirroring [DataSource.getMerchantTagIdsByMerchant]) would let a caller
/// wire this up without changing this sheet's contract.
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
          enabled: false,
          onChanged: (value) =>
              onChanged(filters.copyWith(rewardAvailableOnly: value)),
        ),
      ],
    );
  }
}

class _HideVisitedToggle extends StatelessWidget {
  const _HideVisitedToggle({required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ToggleRow(
      label: 'Ocultar visitados',
      value: filters.hideVisited,
      onChanged: (value) => onChanged(filters.copyWith(hideVisited: value)),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// When `false`, the switch renders disabled (grayed out, `onChanged:
  /// null`) with a "Próximamente" badge next to the label — for a filter
  /// that's modeled in [SearchFilters] but not yet applied by
  /// `applySearchFilters` (see [_BasicoCategory]/[_PremiosCategory]'s doc
  /// comments for why). Found by review: a real toggle with no visual
  /// difference from a working one, that silently does nothing when
  /// applied, is the same "looks functional, isn't" defect as an earlier
  /// bug in the Regalar screen — this makes the gap visible instead of
  /// silent.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: enabled
                      ? AppTheme.body
                      : AppTheme.body.copyWith(color: AppTheme.textTertiary),
                ),
              ),
              if (!enabled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Próximamente',
                    style: AppTheme.body.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: enabled ? onChanged : null),
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

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.activeCount,
    required this.onClear,
    required this.onApply,
  });

  final int activeCount;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final countLabel = activeCount == 0
        ? 'Sin filtros activos'
        : activeCount == 1
        ? '1 filtro activo'
        : '$activeCount filtros activos';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(countLabel, style: AppTheme.bodySecondary),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Limpiar'),
              ),
              const SizedBox(width: 12),
              Expanded(child: _ApplyButton(onTap: onApply)),
            ],
          ),
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
