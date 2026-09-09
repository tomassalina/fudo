import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../../data/providers.dart';
import 'search_utils.dart';

/// Size (px) of the "you are here" marker's hit box — matches web's
/// `USER_LOCATION_ICON_SIZE` in `LeafletMap.tsx` (post `966b371`).
const double _userLocationMarkerSize = 34;

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

  /// Owns pan/zoom programmatically (bug fix 2026-09-09, product-reported
  /// missing "locate me" button): previously `FlutterMap` used its default
  /// internal controller, which nothing outside the widget could drive.
  /// Needed so [_LocateMeButton] can re-center the camera on tap instead of
  /// only being able to set a one-time `initialCenter`.
  final MapController _mapController = MapController();

  /// Matches web's `LOCATE_MIN_ZOOM` (`LeafletMap.tsx`): locating never
  /// zooms *out* past this level even if the map is currently zoomed out
  /// further, but it also never zooms in past whatever the user already
  /// set.
  static const double _locateMinZoom = AppConstants.defaultMapZoom;

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

        // FlutterMap keeps the same State (and its internal MapController)
        // across rebuilds as long as this widget isn't remounted — nothing
        // below assigns it a new `key` or recreates it on filter/query
        // changes, so re-filtering `filtered` only replaces the
        // `MarkerLayer.markers` list in place; pan/zoom survive, matching
        // web's fix (966b371) of not remounting `LeafletMap` while
        // searching/filtering in map mode.
        return ValueListenableBuilder<LatLng?>(
          // Reuses the app's single existing geolocation source
          // (`core/location/location_service.dart`'s app-wide
          // `userLocationController`, already populated by the home
          // header's "Activar ubicación" flow) — this view only ever reads
          // it, it never calls `requestLocation()` itself. `null` (never
          // requested, denied, or a platform failure — see
          // `UserLocationController`'s doc comment) just renders the map
          // with no "you are here" marker: no fake position, no forced
          // re-prompt, no crash. Mirrors web's `userLocation` prop contract
          // in `LeafletMap.tsx` post-966b371.
          valueListenable: userLocationController,
          builder: (context, userLocation, _) {
            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // Bug fix 2026-09-09 (product-reported: map defaulted to
                    // a fixed Palermo center even with the user's real
                    // location known): a fresh/unfiltered view
                    // (`widget.query.isEmpty`) reads straight off
                    // [userLocationController] the same way the "you are
                    // here" marker below does — passive read only, no
                    // forced location request from here — and falls back to
                    // [AppConstants.defaultMapCenter] only when that isn't
                    // available. `initialCenter` is genuinely read only
                    // once, on this `FlutterMap`'s first build (see the
                    // class doc comment on State reuse across rebuilds), so
                    // this doesn't fight [_LocateMeButton] or later
                    // `userLocation` updates once the map is already
                    // mounted.
                    initialCenter: widget.query.isEmpty && userLocation != null
                        ? userLocation
                        : AppConstants.defaultMapCenter,
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
                            point: LatLng(
                              merchant.latitude,
                              merchant.longitude,
                            ),
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
                    // Its own layer, painted after the merchants' layer, so
                    // it always renders above every pin — analogous to
                    // web's `zIndexOffset={1000}` on the equivalent
                    // `Marker`.
                    if (userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: userLocation,
                            width: _userLocationMarkerSize,
                            height: _userLocationMarkerSize,
                            alignment: Alignment.center,
                            // Purely informational, never a tap target —
                            // same intent as web's `interactive={false}`.
                            child: const IgnorePointer(
                              child: _UserLocationMarker(),
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'CARTO',
                          onTap: () =>
                              _openLink('https://carto.com/attributions'),
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
                // "Locate me" (bug fix 2026-09-09, product-reported: this
                // button was completely missing, before and after granting
                // permission). Bottom-left, matching web's equivalent
                // (`web/components/features/buscar/LeafletMap.tsx`'s
                // `bottom-4 left-4` button + `my_location` icon) — unlike
                // web's passive-only version (only rendered once a position
                // already exists), this one is always present so a
                // not-yet-granted visitor has something to tap in the first
                // place; see [_handleLocateMeTap].
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: _LocateMeButton(onTap: _handleLocateMeTap),
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

  /// [_LocateMeButton]'s tap handler (bug fix 2026-09-09). Two cases, same
  /// as the product report:
  ///  - Permission not yet granted (`userLocationController.value == null`):
  ///    reuses [UserLocationController.requestLocation] — the exact same
  ///    permission-request path the home header's "Activar ubicación" pill
  ///    already calls — instead of a second, parallel permission flow.
  ///  - Permission already granted (a resolved value already sitting in
  ///    the controller): pans straight to it, no new location fetch.
  ///
  /// If a fresh request still resolves to `null` (denied, services off, or
  /// any platform failure — see [UserLocationController]'s contract), this
  /// silently no-ops: same "never throws, just stays at no real location"
  /// contract as everywhere else this controller is read.
  Future<void> _handleLocateMeTap() async {
    var location = userLocationController.value;
    if (location == null) {
      await userLocationController.requestLocation();
      location = userLocationController.value;
    }
    if (location == null || !mounted) return;
    _mapController.move(
      location,
      math.max(_mapController.camera.zoom, _locateMinZoom),
    );
  }
}

/// "You are here" marker — a Google-Maps-style blue dot with a pulsing
/// accuracy halo. Deliberately distinct from [_MapPin] (no merchant-type
/// color, no tail, no label): it isn't a merchant, and blue isn't used by
/// any [MerchantType] color, so it never reads as "just another pin".
/// Mirrors web's `createUserLocationIcon` + `.fudo-map-user-location*` CSS
/// (`leaflet-map.css`, post-966b371) — same 34px box, 14px dot, animated
/// halo scaling 0.55→1 while fading out over ~2.4s, looping.
class _UserLocationMarker extends StatefulWidget {
  const _UserLocationMarker();

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _userLocationMarkerSize,
      height: _userLocationMarkerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final t = _pulseController.value;
              return Opacity(
                opacity: (1 - t) * 0.9,
                child: Transform.scale(
                  scale: 0.55 + (0.45 * t),
                  child: Container(
                    width: _userLocationMarkerSize,
                    height: _userLocationMarkerSize,
                    decoration: const BoxDecoration(
                      color: Color(0x594285F4), // rgba(66, 133, 244, 0.35)
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Locate me" floating button (bug fix 2026-09-09) — a circular button,
/// bottom-left, matching web's equivalent in
/// `web/components/features/buscar/LeafletMap.tsx` (`h-10 w-10
/// rounded-full border border-border bg-surface`, `my_location` icon).
/// Purely presentational; [_SearchMapViewState._handleLocateMeTap] owns the
/// permission-request-or-pan behavior.
class _LocateMeButton extends StatelessWidget {
  const _LocateMeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
      elevation: 8,
      shadowColor: AppTheme.shadow,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Symbols.my_location,
            size: 20,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
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
