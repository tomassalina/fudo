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

/// How many logical pixels the content must scroll in one direction before
/// that direction "counts" toward hiding/showing the nav — mirrors the
/// default `threshold` in the web reference's scroll-direction hook
/// (`web/lib/hooks/use-scroll-direction.ts`), so both platforms feel the
/// same on a shared demo device.
const double _scrollHideThreshold = 8;

/// While the scrollable is within this many pixels of the top, the nav
/// always stays visible regardless of direction — same as the web hook's
/// `topOffset` default (there's no content above to have scrolled past).
const double _scrollHideTopOffset = 0;

/// Bottom navigation shell shared by the four main tabs (Inicio, Search,
/// My Places, Gifting). Wraps whatever branch go_router is currently
/// showing and drives navigation via [onTap].
///
/// Visually this is the design brief's "pill" bottom nav (§2.10), rebuilt to
/// match the web mobile nav (`web/components/layout/nav/PhoneNav.tsx`,
/// commit `5e0fbd3` and the auto-hide follow-up): every item — including
/// the QR action — sits flat at the same level (no raised/elevated FAB
/// anymore), and the whole pill hides on scroll-down / reappears on
/// scroll-up.
///
/// **Known gap vs. the web reference (intentionally left out of this
/// change):** the web nav's 5th slot is an always-visible Perfil/Login item
/// (`nav-items.ts`'s `phoneNavRight`) that swaps between a profile route and
/// `/login` depending on auth state. Flutter has no profile or login screen
/// yet (only `features/auth/register_screen.dart` exists) and its 4th
/// routable tab is "Mis Lugares", which has no equivalent in the web nav or
/// the design reference's `tabDefs` (`docs/design-reference/Fudo App.dc.html`).
/// Porting the Perfil/Login behavior would mean either fabricating a
/// destination for a screen that doesn't exist, or removing "Mis Lugares"
/// outright — both are product decisions, not implementation details, so
/// they're left for the product owner rather than guessed under time
/// pressure. `isLoggedInProvider` (`data/providers.dart`) is already
/// available for whoever picks this up next.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    required this.currentIndex,
    required this.onTap,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _navVisible = true;
  double _lastScrollY = 0;

  void _openQrSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LoyaltyQrSheet(initialTab: LoyaltyQrTab.miQr),
    );
  }

  void _handleTap(int index) {
    ref.read(analyticsServiceProvider).trackTabChanged(_tabNames[index]);
    widget.onTap(index);
  }

  /// Direction-based show/hide, ported from the web reference's
  /// `useScrollDirection` (`web/lib/hooks/use-scroll-direction.ts`): stays
  /// visible near the top of the scrollable, hides once the content
  /// scrolls down past [_scrollHideThreshold], and reappears the moment it
  /// scrolls back up. Only vertical scroll notifications count, so a nested
  /// horizontal carousel (e.g. a featured-places row) bubbling its own
  /// [ScrollNotification] doesn't flicker the nav.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    final currentY = notification.metrics.pixels;
    final delta = currentY - _lastScrollY;

    if (currentY <= _scrollHideTopOffset) {
      _lastScrollY = currentY;
      if (!_navVisible) setState(() => _navVisible = true);
      return false;
    }

    if (delta.abs() < _scrollHideThreshold) return false;

    final goingDown = delta > 0;
    _lastScrollY = currentY;
    if (_navVisible == goingDown) {
      setState(() => _navVisible = !goingDown);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The pill floats over the content instead of pushing it up — the
      // body draws behind the nav bar's transparent margins.
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: widget.child,
      ),
      bottomNavigationBar: _FloatingBottomNav(
        currentIndex: widget.currentIndex,
        visible: _navVisible,
        onTap: _handleTap,
        onQrTap: () => _openQrSheet(context),
      ),
    );
  }
}

/// The floating pill itself: a blurred, semi-transparent bar holding all 5
/// destinations flat — 4 routable tabs plus the QR quick action, none
/// raised above the others (see `PhoneNav.tsx`'s `TabLink`/`TabButton`) —
/// and animated in/out of view per [visible].
class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.visible,
    required this.onTap,
    required this.onQrTap,
  });

  final int currentIndex;
  final bool visible;
  final ValueChanged<int> onTap;
  final VoidCallback onQrTap;

  static const double _pillHeight = 64;
  static const Duration _visibilityDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    // pointer-events-none while hidden (web's `translate-y-24 opacity-0
    // pointer-events-none`) — IgnorePointer keeps a hidden pill from eating
    // taps on content underneath it.
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: _visibilityDuration,
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(0, 1.6),
        child: AnimatedOpacity(
          duration: _visibilityDuration,
          curve: Curves.easeOut,
          opacity: visible ? 1 : 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              bottomSafeArea > 0 ? bottomSafeArea + 8 : 20,
            ),
            child: ClipRRect(
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
                      _FlatQrButton(onTap: onQrTap),
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
          ),
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

/// QR quick action, flat at the same level as the other nav items — no
/// raised/elevated circular FAB treatment. An earlier version raised this
/// as a circle dipping above the pill; the real reference design has no
/// such elevation (see `PhoneNav.tsx`'s doc comment and `TabButton`, and
/// `openspec/changes/fudo-consumers-mvp/learnings.md` Decisión 19, which
/// documents this exact product correction on the web side). Opens
/// [LoyaltyQrSheet] directly — it does not change [MainShell.currentIndex]
/// or participate in tab navigation, so unlike [_NavItem] it never renders
/// a label or an active/selected state.
class _FlatQrButton extends StatelessWidget {
  const _FlatQrButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Icon(
          Symbols.qr_code_scanner,
          color: AppTheme.textTertiary,
          size: 24,
        ),
      ),
    );
  }
}
