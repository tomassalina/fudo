import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/merchant.dart';
import '../../../data/providers.dart';
import 'search_utils.dart' show merchantTypeLabel;

/// Home/landing view for the "Buscar" tab (design-brief §2.1): headline,
/// floating search card with a typewriter-style animated placeholder, and an
/// optional "CONTINUAR BÚSQUEDA" block surfacing the consumer's last search.
///
/// Also reused as-is by the "Inicio" tab (`features/home/home_screen.dart`)
/// for its hero, mirroring web's home hero
/// (`components/features/home/HeroSearch.tsx`) — that web component has NO
/// "continue last search" affordance at all (confirmed by reading it), so
/// [showContinueSearch] lets a caller opt out of that block without touching
/// this widget's behavior for whoever else legitimately renders it with the
/// block on (default `true`, unchanged from before).
class SearchHomeView extends ConsumerStatefulWidget {
  const SearchHomeView({
    required this.onSearch,
    this.showContinueSearch = true,
    super.key,
  });

  /// Called with the submitted query text — either typed by the user or the
  /// "continuar búsqueda" shortcut.
  final ValueChanged<String> onSearch;

  /// Whether to render the "CONTINUAR BÚSQUEDA" block when a last search
  /// exists. See class doc — defaults to `true` so existing callers are
  /// unaffected.
  final bool showContinueSearch;

  @override
  ConsumerState<SearchHomeView> createState() => _SearchHomeViewState();
}

class _SearchHomeViewState extends ConsumerState<SearchHomeView> {
  static const _hints = [
    'Algo picante y barato cerca mío',
    'Café tranquilo para laburar en Palermo',
    'Parrilla para ir con amigos esta noche',
    'Opción sin TACC para almorzar',
    'Sushi que no sea carísimo',
  ];

  /// Mirrors web's `pb-28` (112px) bottom-nav clearance subtracted from
  /// `HeroSection.tsx`'s centering box — see the centering comment in
  /// [build] for why this widget needs the same number. Added as an
  /// invisible trailing spacer inside the centered [Column] rather than
  /// subtracted from the box height itself: centering a group whose last
  /// child is this spacer shifts the *visible* content (everything above
  /// it) up by exactly half the spacer's height, which is the same
  /// arithmetic effect as web's "shrink the box, then center" approach.
  static const _bottomNavClearance = 112.0;

  static const _typeDelay = Duration(milliseconds: 45);
  static const _deleteDelay = Duration(milliseconds: 25);
  static const _pauseAfterTyped = Duration(milliseconds: 1400);
  static const _pauseAfterDeleted = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  String _displayedHint = '';
  int _hintIndex = 0;
  int _charCount = 0;
  bool _deleting = false;
  Timer? _timer;

  /// Visual-only type filter, matching web's `HeroSearch.tsx` type-filter
  /// pill (`selectedType`/`TYPE_OPTIONS`, "Cualquiera" = `null`). Not wired
  /// into `widget.onSearch` (still `String`-only) on purpose: threading it
  /// through to the real search filters means touching `search_screen.dart`
  /// / `SearchScreenInitial`, which is out of this widget's scope — see
  /// `home/home_screen.dart` for where that handoff happens.
  MerchantType? _selectedType;

  Future<void> _pickType() async {
    final picked = await showModalBottomSheet<_TypeOption>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (context) => _TypeSheet(selected: _selectedType),
    );
    if (picked != null) {
      setState(() => _selectedType = picked.value);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scheduleTick(_typeDelay);
  }

  void _onTextChanged() => setState(() {});

  /// Drives the typewriter placeholder with a self-rescheduling [Timer]
  /// (types a hint character by character, pauses, deletes it, moves to the
  /// next hint) instead of a package. Using a real, cancelable `Timer` (kept
  /// in [_timer]) rather than a chain of `Future.delayed` calls matters here:
  /// widget tests fail their "no pending timers" invariant if a delayed
  /// future is still in flight when the widget is disposed, even if a
  /// `mounted` check would have made it a no-op — an explicit `_timer
  /// ?.cancel()` in [dispose] avoids that entirely.
  void _scheduleTick(Duration delay) {
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted) return;
    final phrase = _hints[_hintIndex];
    setState(() {
      if (!_deleting) {
        if (_charCount < phrase.length) {
          _charCount++;
          _displayedHint = phrase.substring(0, _charCount);
          _scheduleTick(_typeDelay);
        } else {
          _deleting = true;
          _scheduleTick(_pauseAfterTyped);
        }
      } else {
        if (_charCount > 0) {
          _charCount--;
          _displayedHint = phrase.substring(0, _charCount);
          _scheduleTick(_deleteDelay);
        } else {
          _deleting = false;
          _hintIndex = (_hintIndex + 1) % _hints.length;
          _scheduleTick(_pauseAfterDeleted);
        }
      }
    });
  }

  void _submit() {
    final text = _controller.text.trim().isEmpty
        ? _displayedHint
        : _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSearch(text);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchHistory = ref.watch(searchHistoryProvider).value;
    final lastQuery = (searchHistory != null && searchHistory.isNotEmpty)
        ? searchHistory.last.queryText
        : null;

    // Web's hero (`HeroSection.tsx`) centers the headline + search card in
    // the full space left over after chrome instead of pinning it near the
    // top — `LayoutBuilder` + a `minHeight` constraint reproduces that here
    // while still allowing the column to scroll on short screens.
    //
    // Correction from the previous round (commit 8bc4285): that version
    // centered within the *entire* `constraints.maxHeight`, but this widget
    // always renders inside `MainShell` (`shared/widgets/main_shell.dart`),
    // whose `Scaffold` uses `extendBody: true` with a *floating* bottom-nav
    // pill (`_FloatingBottomNav`) that does NOT reserve layout space — so
    // `constraints.maxHeight` already extends behind the pill. Web avoids
    // this by explicitly subtracting `164px` (`~52px` header + `112px`
    // `pb-28`, "the same bottom-nav clearance used everywhere else in this
    // app") from `100vh` *before* centering (`HeroSection.tsx`), since its
    // own `PhoneNav` is equally a floating overlay that reserves no space.
    // `_bottomNavClearance` below mirrors that same `112px` figure — the
    // header offset itself is already handled for free here, since
    // `HomeHeader`/the "Buscar" tab's own top bar sit in a sibling
    // `Column` slot above this `Expanded`, not inside it.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Web's `--text-hero-fluid-phone` token: `clamp(25px, 8.4vw, 36px)`.
        final width = MediaQuery.sizeOf(context).width;
        final headlineSize = (width * 0.084).clamp(25.0, 36.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    // Web: `font-black` (900) + `text-hero-fluid-phone`
                    // (clamp 25-36px, line-height 1.1) — bigger/bolder than
                    // the theme's default headline style.
                    style: AppTheme.headline.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: headlineSize,
                      height: 1.1,
                    ),
                    children: [
                      const TextSpan(text: 'Encontrá dónde comer.\n'),
                      TextSpan(
                        text: 'Ganá descuentos',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppTheme.accent,
                        ),
                      ),
                      const TextSpan(text: ' por cada visita.'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SearchCard(
                  controller: _controller,
                  displayedHint: _displayedHint,
                  selectedType: _selectedType,
                  onPickType: _pickType,
                  onSubmit: _submit,
                ),
                if (widget.showContinueSearch && lastQuery != null) ...[
                  const SizedBox(height: 24),
                  _ContinueSearchBlock(
                    query: lastQuery,
                    onTap: () => widget.onSearch(lastQuery),
                  ),
                ],
                // Invisible trailing spacer — NOT rendered content. See the
                // `_bottomNavClearance` doc comment: this is what actually
                // shifts the visible block above it up and off the floating
                // bottom-nav pill, matching web's centering math.
                const SizedBox(height: _bottomNavClearance),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Two-row search card matching web's `HeroSearch.tsx` phone layout exactly:
/// row 1 is the full-width search input, row 2 is the type-filter pill
/// (left) + round orange arrow submit button (right) — NOT the old single
/// row with an inline magnifying-glass button.
class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.displayedHint,
    required this.selectedType,
    required this.onPickType,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String displayedHint;
  final MerchantType? selectedType;
  final VoidCallback onPickType;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 50,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (controller.text.isEmpty)
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  text: TextSpan(
                    style: AppTheme.body.copyWith(color: AppTheme.textTertiary),
                    children: [
                      TextSpan(text: displayedHint),
                      const TextSpan(text: '|'),
                    ],
                  ),
                ),
              TextField(
                controller: controller,
                style: AppTheme.body,
                onSubmitted: (_) => onSubmit(),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TypeFilterPill(selectedType: selectedType, onTap: onPickType),
              _SubmitButton(onTap: onSubmit),
            ],
          ),
        ],
      ),
    );
  }
}

/// Type-filter pill (icon + label + chevron) — web: the "Cualquiera"/type
/// button next to the arrow submit button, same row, below the input.
class _TypeFilterPill extends StatelessWidget {
  const _TypeFilterPill({required this.selectedType, required this.onTap});

  final MerchantType? selectedType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = selectedType == null
        ? 'Cualquiera'
        : merchantTypeLabel(selectedType!);

    return Material(
      color: AppTheme.surfaceSecondary,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.storefront, size: 17, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Symbols.expand_more,
                size: 16,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One option in `_TypeSheet` — `value == null` is "Cualquiera" (web:
/// `TYPE_OPTIONS`'s `{ value: null, label: "Cualquiera" }`).
class _TypeOption {
  const _TypeOption(this.value, this.label);

  final MerchantType? value;
  final String label;
}

/// Bottom sheet listing "Cualquiera" + every [MerchantType], mirroring web's
/// `HeroSearch.tsx` type-picker `<Sheet>` (`TYPE_OPTIONS`).
class _TypeSheet extends StatelessWidget {
  const _TypeSheet({required this.selected});

  final MerchantType? selected;

  @override
  Widget build(BuildContext context) {
    final options = [
      const _TypeOption(null, 'Cualquiera'),
      for (final type in MerchantType.values)
        _TypeOption(type, merchantTypeLabel(type)),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de lugar',
              style: AppTheme.title.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            for (final option in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label, style: AppTheme.body),
                trailing: option.value == selected
                    ? const Icon(
                        Symbols.check_circle,
                        color: AppTheme.accent,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Web (phone): round button icon is `arrow_forward`, not a
          // magnifying glass — `Symbols.search` was the pre-fix mismatch.
          child: const Icon(Symbols.arrow_forward, color: Colors.white),
        ),
      ),
    );
  }
}

class _ContinueSearchBlock extends StatelessWidget {
  const _ContinueSearchBlock({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.history,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTINUAR BÚSQUEDA',
                      style: AppTheme.body.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      query,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.arrow_forward,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
