import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../features/loyalty/qr_sheet.dart';

/// Tab labels in [MainShell.currentIndex] order, also used as the
/// `tab_name` analytics property (see [AnalyticsService.trackTabChanged]).
const List<String> _tabNames = ['Inicio', 'Buscar', 'Mis Lugares', 'Regalar'];

/// Bottom navigation shell shared by the four main tabs (Inicio, Search,
/// My Places, Gifting). Wraps whatever branch go_router is currently
/// showing and drives navigation via [onTap].
///
/// Visually this is the design brief's "pill" bottom nav (§2.10): a floating,
/// blurred pill — not a standard Material [BottomNavigationBar] pinned flush
/// to the screen edge — with a raised central QR action that opens
/// [LoyaltyQrSheet] instead of taking part in tab navigation.
class MainShell extends ConsumerWidget {
  const MainShell({
    required this.currentIndex,
    required this.onTap,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  void _openQrSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LoyaltyQrSheet(initialTab: LoyaltyQrTab.miQr),
    );
  }

  void _handleTap(WidgetRef ref, int index) {
    ref.read(analyticsServiceProvider).trackTabChanged(_tabNames[index]);
    onTap(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // The pill floats over the content instead of pushing it up — the
      // body draws behind the nav bar's transparent margins.
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingBottomNav(
        currentIndex: currentIndex,
        onTap: (index) => _handleTap(ref, index),
        onQrTap: () => _openQrSheet(context),
      ),
    );
  }
}

/// The floating pill itself: a blurred, semi-transparent bar holding the
/// three tab destinations, with the circular QR action raised above it.
class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onQrTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onQrTap;

  static const double _pillHeight = 64;
  static const double _qrDiameter = 60;

  /// How much of the QR button's circle dips into the pill's top edge.
  /// Kept small on purpose: tab icons sit vertically centered in the pill,
  /// so anything past ~20px would start covering the middle tab's icon.
  static const double _qrOverlapIntoPill = 16;

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        bottomSafeArea > 0 ? bottomSafeArea + 8 : 20,
      ),
      child: SizedBox(
        height: _pillHeight + (_qrDiameter - _qrOverlapIntoPill),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: _pillHeight,
                  decoration: BoxDecoration(
                    color: AppTheme.navBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppTheme.shadow,
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Symbols.home,
                          label: 'Inicio',
                          selected: currentIndex == 0,
                          onTap: () => onTap(0),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Symbols.search,
                          label: 'Buscar',
                          selected: currentIndex == 1,
                          onTap: () => onTap(1),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Symbols.storefront,
                          label: 'Mis Lugares',
                          selected: currentIndex == 2,
                          onTap: () => onTap(2),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Symbols.card_giftcard,
                          label: 'Regalar',
                          selected: currentIndex == 3,
                          onTap: () => onTap(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: _pillHeight - _qrOverlapIntoPill,
              child: _QrButton(onTap: onQrTap),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single tab destination. The label only takes up space and becomes
/// visible when [selected] is true — otherwise it collapses to just the
/// icon, animating width and opacity together via [AnimatedAlign] +
/// [AnimatedOpacity] on the same always-mounted [Text], so the transition
/// interpolates smoothly instead of popping in/out.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent : AppTheme.textTertiary;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            ClipRect(
              child: AnimatedAlign(
                duration: _duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: selected ? 1 : 0,
                child: AnimatedOpacity(
                  duration: _duration,
                  opacity: selected ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Central quick-action button: opens [LoyaltyQrSheet] directly, it does not
/// change [MainShell.currentIndex] or participate in tab navigation.
class _QrButton extends StatelessWidget {
  const _QrButton({required this.onTap});

  final VoidCallback onTap;

  static const double diameter = 60;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.ctaGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Icon(
              Symbols.qr_code_scanner,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
