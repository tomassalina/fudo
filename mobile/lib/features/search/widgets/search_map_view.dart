import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../../data/providers.dart';
import 'search_utils.dart';

/// Map view for the "Buscar" tab (design-brief §2.4): extends the existing
/// `FlutterMap` (CartoDB Dark Matter tiles) with one marker per filtered
/// merchant, a floating mini-card on pin tap, and a button back to the list.
class SearchMapView extends ConsumerStatefulWidget {
  const SearchMapView({
    required this.query,
    required this.onOpenMerchant,
    required this.onBackToList,
    super.key,
  });

  final String query;
  final ValueChanged<int> onOpenMerchant;
  final VoidCallback onBackToList;

  @override
  ConsumerState<SearchMapView> createState() => _SearchMapViewState();
}

class _SearchMapViewState extends ConsumerState<SearchMapView> {
  Merchant? _selected;

  @override
  Widget build(BuildContext context) {
    final merchantsAsync = ref.watch(merchantsProvider);

    return merchantsAsync.when(
      data: (merchants) {
        final filtered = filterMerchants(merchants, widget.query);
        // The previously-selected pin might have been filtered out by a
        // query edited while the map was open — drop the mini-card in that
        // case instead of pointing at a merchant no longer on screen.
        if (_selected != null && !filtered.contains(_selected)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selected = null);
          });
        }

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: AppConstants.defaultMapCenter,
                initialZoom: AppConstants.defaultMapZoom,
                onTap: (_, _) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.cartoDarkMatterTileUrl,
                  userAgentPackageName: 'com.fudo.mobile',
                ),
                MarkerLayer(
                  markers: [
                    for (final merchant in filtered)
                      Marker(
                        point: LatLng(merchant.latitude, merchant.longitude),
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: _MapPin(
                          merchant: merchant,
                          selected: _selected?.id == merchant.id,
                          onTap: () => setState(() => _selected = merchant),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'CARTO',
                      onTap: () => _openLink('https://carto.com/attributions'),
                    ),
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => _openLink(
                        'https://www.openstreetmap.org/copyright',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'search-map-back-to-list',
                onPressed: widget.onBackToList,
                backgroundColor: AppTheme.surface,
                foregroundColor: AppTheme.textPrimary,
                child: const Icon(Symbols.view_list),
              ),
            ),
            if (_selected != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: _MiniCard(
                  merchant: _selected!,
                  onTap: () => widget.onOpenMerchant(_selected!.id),
                ),
              ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (error, stackTrace) => Center(
        child: Text(
          'No pudimos cargar el mapa.',
          style: AppTheme.bodySecondary,
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.merchant,
    required this.selected,
    required this.onTap,
  });

  final Merchant merchant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = merchant.type.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.15 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : AppTheme.background,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(merchant.type.icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.merchant, required this.onTap});

  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priceLabel = formatPriceRange(merchant);
    final distanceLabel = formatDistance(distanceKmFromUser(merchant));

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      elevation: 8,
      shadowColor: AppTheme.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppTheme.radiusPhotoSmall,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: merchant.coverImageUrl == null
                      ? Container(
                          color: merchant.type.color.withValues(alpha: 0.18),
                          child: Icon(
                            merchant.type.icon,
                            color: merchant.type.color,
                          ),
                        )
                      : Image.network(
                          merchant.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: merchant.type.color.withValues(
                                  alpha: 0.18,
                                ),
                                child: Icon(
                                  merchant.type.icon,
                                  color: merchant.type.color,
                                ),
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      merchant.name,
                      style: AppTheme.title.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (priceLabel != null) ...[
                          Text(
                            priceLabel,
                            style: AppTheme.body.copyWith(
                              color: AppTheme.priceChipText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          Symbols.near_me,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(distanceLabel, style: AppTheme.bodySecondary),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
