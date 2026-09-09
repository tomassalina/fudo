import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../search/widgets/search_utils.dart';

/// "Lugares destacados" row for the "Inicio" tab — analogous to
/// `web/components/features/home/FeaturedGrid.tsx`: the first
/// [maxItems] merchants, each a compact photo card with type badge, name,
/// neighborhood, price-from chip and distance.
///
/// Flutter has no wide/phone breakpoint split like the web version (whose
/// `isPhone` flag switches between a horizontal-scroll row and a CSS grid);
/// this is always the horizontal-scroll row, which is the correct layout
/// for a phone app.
class FeaturedGrid extends StatelessWidget {
  const FeaturedGrid({
    required this.merchants,
    required this.onOpenMerchant,
    super.key,
  });

  final List<Merchant> merchants;
  final ValueChanged<int> onOpenMerchant;

  /// Same cap the web reference uses (`web/app/(marketing)/page.tsx`'s
  /// `FEATURED_COUNT`).
  static const int maxItems = 6;

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return const SizedBox.shrink();
    final featured = merchants.take(maxItems).toList();

    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final merchant = featured[index];
          return SizedBox(
            width: 168,
            child: _FeaturedCard(
              merchant: merchant,
              onTap: () => onOpenMerchant(merchant.id),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.merchant, required this.onTap});

  final Merchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typePresentation = merchant.type;
    final priceLabel = merchant.pricePerPersonMin != null
        ? 'desde ${formatMoney(merchant.pricePerPersonMin!)}'
        : null;

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
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CoverImage(
                    imageUrl: merchant.coverImageUrl,
                    typeColor: typePresentation.color,
                    typeIcon: typePresentation.icon,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _TypeBadge(type: merchant.type),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: AppTheme.title.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    merchant.neighborhood ?? merchant.city,
                    style: AppTheme.body.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (priceLabel != null) ...[
                        Flexible(child: _PriceChip(label: priceLabel)),
                        const SizedBox(width: 6),
                      ],
                      // Rebuilds just this label when the user activates/
                      // clears their real location — the rest of the card
                      // (photo, badge, name) never changes because of it.
                      ValueListenableBuilder<LatLng?>(
                        valueListenable: userLocationController,
                        builder: (context, _, _) => Text(
                          formatDistance(distanceKmFromUser(merchant)),
                          style: AppTheme.body.copyWith(
                            color: AppTheme.textTertiary,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
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
      child: Icon(typeIcon, color: typeColor, size: 28),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final MerchantType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
      child: Icon(type.icon, color: Colors.white, size: 14),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.priceChipBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: AppTheme.body.copyWith(
          color: AppTheme.priceChipText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
