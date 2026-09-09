import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';

/// Global top header for the "Inicio" tab: the Fudo wordmark plus the
/// "Activar ubicación" pill — analogous to `web/components/layout/
/// Header.tsx` + `LocationButton.tsx`.
///
/// Unlike the web version (phone-only chrome, hidden at wide viewports —
/// wide layouts get their own sticky top bar), Flutter has no separate wide
/// layout, so this is the only header the app has and always renders here.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'fudo',
          style: AppTheme.title.copyWith(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppTheme.accent,
          ),
        ),
        const _LocationPill(),
      ],
    );
  }
}

/// The "Activar ubicación" pill itself (`web/components/layout/
/// LocationButton.tsx`): tapping it while inactive requests the real device
/// location via [userLocationController]; tapping it while active clears it.
/// Only icon/color/label react to whether a location is set — same as the
/// web reference, which doesn't attempt reverse-geocoding either.
class _LocationPill extends StatefulWidget {
  const _LocationPill();

  @override
  State<_LocationPill> createState() => _LocationPillState();
}

class _LocationPillState extends State<_LocationPill> {
  bool _requesting = false;

  Future<void> _handleTap(LatLng? current) async {
    if (_requesting) return;
    if (current != null) {
      userLocationController.clearLocation();
      return;
    }
    setState(() => _requesting = true);
    await userLocationController.requestLocation();
    if (mounted) setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: userLocationController,
      builder: (context, location, _) {
        final active = location != null;
        final color = active ? AppTheme.accent : AppTheme.textTertiary;

        return Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: InkWell(
            onTap: _requesting ? null : () => _handleTap(location),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_requesting)
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(
                      active
                          ? Symbols.my_location
                          : Symbols.location_disabled,
                      size: 17,
                      color: color,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    active ? 'Ubicación activada' : 'Activar ubicación',
                    style: AppTheme.body.copyWith(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
