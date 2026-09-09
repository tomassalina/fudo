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

/// Height (px) of the floating bottom nav pill itself, not counting the
/// safe-area gap below it. Exposed as a real shared constant (bug fix
/// 2026-09-09, product-reported floating "Mapa" button mispositioned) so
/// anything that needs to float just above the nav — e.g.
/// `features/search/search_screen.dart`'s floating "Mapa" button — can
/// anchor a robust relative offset instead of a magic number that only
/// happened to match on one device/safe-area combination.
const double mainShellNavPillHeight = 64;

/// Bottom margin (px) reserved below the nav pill, as a pure function of
/// [MediaQuery]'s safe-area inset — the exact formula [_FloatingBottomNav]
/// itself uses for its own bottom padding — so a caller elsewhere in the
/// tree (no access to the nav's own subtree/context) can compute the
/// identical number instead of guessing it.
double mainShellNavBottomMargin(BuildContext context) {
  final bottomSafeArea = MediaQuery.of(context).padding.bottom;
  return bottomSafeArea > 0 ? bottomSafeArea + 8 : 20;
}

/// Shared scroll-visibility signal (bug fix 2026-09-09): true while the
/// floating bottom nav pill is visible, false while scroll-down has hidden
/// it. [_MainShellState._handleScrollNotification] is the sole writer (it
/// already owns the one `NotificationListener<ScrollNotification>` for the
/// whole shell); anything else that must hide/show in sync with the nav
/// (e.g. `SearchScreen`'s floating "Mapa" button) reads this instead of
/// standing up a second, independently-timed scroll listener that could
/// drift out of sync with the nav's own visibility.
class NavVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) => state = visible;
}

/// See [NavVisibleNotifier].
final navVisibleProvider = NotifierProvider<NavVisibleNotifier, bool>(
  NavVisibleNotifier.new,
);

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
    final navVisible = ref.read(navVisibleProvider);

    if (currentY <= _scrollHideTopOffset) {
      _lastScrollY = currentY;
      if (!navVisible) ref.read(navVisibleProvider.notifier).setVisible(true);
      return false;
    }

    if (delta.abs() < _scrollHideThreshold) return false;

    final goingDown = delta > 0;
    _lastScrollY = currentY;
    if (navVisible == goingDown) {
      ref.read(navVisibleProvider.notifier).setVisible(!goingDown);
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
        visible: ref.watch(navVisibleProvider),
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

  static const Duration _visibilityDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
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
              mainShellNavBottomMargin(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: mainShellNavPillHeight,
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
                          selected: currentIndex == 0,
                          onTap: () => onTap(0),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Symbols.search,
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
                          selected: currentIndex == 3,
                          onTap: () => onTap(3),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: isLoggedIn ? Symbols.person : Symbols.login,
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

/// A single tab destination. Icon-only, always — never a text label, active
/// or inactive (product correction, 2026-09-09: an earlier version revealed
/// a white label next to the icon on the active tab; the product owner
/// wants icons only, ever, with just the orange illumination signaling the
/// active tab).
///
/// Selected styling matches `PhoneNav.tsx`'s `TabLink` active state's icon
/// treatment: a `bg-gradient-to-b from-cta-from to-cta-to` pill
/// ([AppTheme.ctaGradient] — its stops are the same `#ff6337`/`#e8431a` as
/// the web tokens in `web/app/globals.css`) with `shadow-cta`'s warm glow
/// and a white icon, vs. the flat/borderless muted `text-foreground-faint`
/// ([AppTheme.textTertiary]) treatment when inactive.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppTheme.textTertiary;

    // InkWell fills the whole equal-width `Expanded` slot the parent Row
    // gives each tab (same generous tap target as before) — but `Center`
    // hands its child LOOSE constraints instead of forwarding that slot's
    // tight width down, so the decorated pill itself shrink-wraps to just
    // the icon + padding instead of stretching edge-to-edge across the
    // slot. Without `Center` here, an icon-only `AnimatedContainer` (no
    // intrinsic width preference of its own) would be forced to the full
    // slot width by those tight constraints and paint as an oddly-wide
    // rectangle behind a single centered icon — exactly the pill shape
    // that was sized to fit icon+text before, now wrong with text gone.
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Center(
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.ctaGradient : null,
            // A square 48x48 box (24px icon + 12px padding each side) at
            // [AppTheme.radiusPill] (999) renders as a true circle, not a
            // stadium — matches "icon lights up orange" instead of an
            // odd icon-in-a-pill look.
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
          child: Icon(icon, color: color, size: 24),
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
