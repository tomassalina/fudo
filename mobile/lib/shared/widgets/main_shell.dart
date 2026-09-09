import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../features/loyalty/qr_sheet.dart';

/// Tab labels in [MainShell.currentIndex] order, also used as the
/// `tab_name` analytics property (see [AnalyticsService.trackTabChanged]).
/// Index 2 ("Perfil"/"Ingresar" nav slot) is auth-dependent — see
/// [_MainShellState._handleTap], which swaps in the live label before
/// tracking — this static entry is only the logged-out-friendly fallback.
const List<String> _tabNames = ['Inicio', 'Buscar', 'Perfil', 'Regalar'];

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
/// Matches the web nav's 5-slot composition and order exactly
/// (`web/components/layout/nav/PhoneNav.tsx` + `nav-items.ts`): Inicio,
/// Buscar, QR (a button, not a route), Regalar, then Perfil as the always
/// -visible 5th slot. The old "Mis Lugares" tab (index 2, still routes to
/// [AppRoutes.myPlaces] — the feature folder/route are intentionally
/// unrenamed) is that Perfil slot: its label/icon swap on [isLoggedInProvider]
/// — "Perfil"/[Symbols.person] when logged in, "Ingresar"/[Symbols.login]
/// when logged out — same pattern as web's `phoneNavRight(isAuthenticated)`.
/// Flutter has no standalone `/login` route (unlike web); [AppRoutes.myPlaces]
/// already embeds the login form for a logged-out consumer (see
/// `features/my_places/my_places_screen.dart`), so it doubles as both
/// destinations without inventing a new route. The QR button
/// ([_MainShellState._openQrSheet]) is auth-gated the same way: logged in
/// opens [LoyaltyQrSheet], logged out redirects to [AppRoutes.myPlaces]
/// instead of opening anything, mirroring web's `handleOpenQr`.
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

  /// Auth-gated QR quick action, mirroring web's `handleOpenQr`: a logged-in
  /// consumer sees their own loyalty QR; a logged-out visitor has no QR to
  /// show, so this redirects to [AppRoutes.myPlaces] (the embedded-login
  /// screen — see the class doc comment) instead of opening anything.
  void _openQrSheet(BuildContext context) {
    if (!ref.read(isLoggedInProvider)) {
      context.go(AppRoutes.myPlaces);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LoyaltyQrSheet(initialTab: LoyaltyQrTab.miQr),
    );
  }

  void _handleTap(int index) {
    // Index 2 is the auth-dependent Perfil/Ingresar slot (see class doc
    // comment) — track the label the user actually saw, not the static
    // logged-out fallback in [_tabNames].
    final tabName = index == 2 && ref.read(isLoggedInProvider)
        ? 'Perfil'
        : _tabNames[index];
    ref.read(analyticsServiceProvider).trackTabChanged(tabName);
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
        isLoggedIn: ref.watch(isLoggedInProvider),
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
    required this.isLoggedIn,
    required this.onTap,
    required this.onQrTap,
  });

  final int currentIndex;
  final bool visible;
  final bool isLoggedIn;
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
                    // `--shadow-nav: 0 14px 34px var(--shadow)`
                    // (web/app/globals.css).
                    boxShadow: const [
                      BoxShadow(
                        color: AppTheme.shadow,
                        blurRadius: 34,
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
                      // Order matches web's `phoneNavRight` exactly: Regalar
                      // before the always-visible Perfil/Ingresar slot (see
                      // class doc comment) — visual order only, [onTap]
                      // still passes each item's real tab index (3 for
                      // Regalar, 2 for Perfil/Mis Lugares) so routing in
                      // `app_router.dart` is untouched.
                      Expanded(
                        child: _NavItem(
                          icon: Symbols.card_giftcard,
                          label: 'Regalar',
                          selected: currentIndex == 3,
                          onTap: () => onTap(3),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: isLoggedIn ? Symbols.person : Symbols.login,
                          label: isLoggedIn ? 'Perfil' : 'Ingresar',
                          selected: currentIndex == 2,
                          onTap: () => onTap(2),
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
///
/// Selected styling matches `PhoneNav.tsx`'s `TabLink` active state exactly:
/// a `bg-gradient-to-b from-cta-from to-cta-to` pill ([AppTheme.ctaGradient]
/// — its stops are the same `#ff6337`/`#e8431a` as the web tokens in
/// `web/app/globals.css`) with `shadow-cta`'s warm glow and white
/// icon+label text, vs. the flat/borderless muted `text-foreground-faint`
/// ([AppTheme.textTertiary]) treatment when inactive.
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
    final color = selected ? Colors.white : AppTheme.textTertiary;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.ctaGradient : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          // `--shadow-cta: 0 8px 20px rgba(255, 80, 35, 0.34), inset 0 1px 0
          // rgba(255, 255, 255, 0.26)` (web/app/globals.css) — the outer
          // warm glow only; Flutter's BoxShadow has no inset variant, so the
          // inner highlight isn't reproduced.
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.34),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
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
                        color: Colors.white,
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
