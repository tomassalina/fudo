import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// `flutter_riverpod` exports its own `Consumer` widget, which clashes with
// our domain `Consumer` model — hidden the same way
// `features/my_places/my_places_screen.dart` does, even though this file
// doesn't need the domain model directly (keeps the convention consistent).
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/formatting/currency_format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/connection_mode.dart';
import '../../data/models/gift.dart';
import '../../data/providers.dart';

/// "Regalar" tab: buy and send a Fudo gift card to another person.
///
/// In [ConnectionMode.local] (the default), "buying" a gift card is entirely
/// local UI state that culminates in a success overlay, matching the Claude
/// Design prototype (see `docs/design-brief.md` §2.6 and §3) — no backend
/// call is ever made.
///
/// In [ConnectionMode.remote], the CTA calls the real
/// `DataSource.createGift` (`POST /api/v1/gifts`) before showing the success
/// overlay — same "real call gated by connection mode, with loading/error
/// handling" pattern as `features/my_places/my_places_screen.dart`'s login
/// flow. On failure, the success overlay is never shown and the form is
/// never reset.
///
/// Session gate (`docs/flutter-vs-nextjs-gap-report.md`, Tarea 4): anyone
/// can still browse the tier tiles, but the checkout fields (recipient
/// phone, message, CTA) are replaced by [_LoginRequiredCard] while
/// [isLoggedInProvider] is `false` — analogous to
/// `web/components/features/regalar/LoginRequiredCard.tsx`, which gates the
/// same way on `useSession().isAuthenticated`.
///
/// Decision (documented per the task's explicit "opcional, usá criterio"):
/// login stays embedded in `MyPlacesScreen` for now instead of getting its
/// own route — lower risk, smaller scope. So [_LoginRequiredCard]'s CTA
/// navigates to the "Mis Lugares"/Perfil tab (`AppRoutes.myPlaces`), which
/// shows that embedded login form, instead of a dedicated `/login` route
/// the web reference links to (`/perfil`).
class GiftingScreen extends ConsumerStatefulWidget {
  const GiftingScreen({super.key});

  @override
  ConsumerState<GiftingScreen> createState() => _GiftingScreenState();
}

class _GiftingScreenState extends ConsumerState<GiftingScreen>
    with SingleTickerProviderStateMixin {
  // Card + inter-card spacing, used to center a tapped card programmatically
  // (see [_selectTier]).
  static const _cardWidth = 250.0;
  static const _cardSpacing = 16.0;
  static const _cardExtent = _cardWidth + _cardSpacing;

  final ScrollController _carouselController = ScrollController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  /// Drives the idle shimmer/sheen sweep shared by the 4 tier cards and the
  /// CTA button — a single controller (instead of one per widget) keeps
  /// every sweep in lockstep, matching the web reference's shared
  /// `[animation-duration:3.6s]` override on `animate-fudo-sheen`
  /// (`GiftTierPicker.tsx`, `GiftCheckoutForm.tsx`).
  late final AnimationController _sheenController;

  int _selectedIndex = 0;

  /// `true` while a real [ConnectionMode.remote] `createGift` request is in
  /// flight. Always `false` in [ConnectionMode.local] — that path never
  /// awaits anything, same as `my_places_screen.dart`'s login flow.
  bool _isSubmitting = false;

  /// Set when a real remote `createGift` attempt fails — shown under the CTA
  /// button, cleared on the next submit attempt. Always `null` in
  /// [ConnectionMode.local].
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _carouselController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  GiftType get _selectedType => GiftType.values[_selectedIndex];

  bool get _isCustomAmount => _selectedType.customAmountRange != null;

  /// `null` when there's no error to show (either the field is empty, or
  /// the amount is valid, or the tier has no custom amount at all).
  String? get _amountError {
    if (!_isCustomAmount) return null;
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    if (RegExp(r'[^0-9]').hasMatch(text)) return 'Usá solo números';
    final value = double.tryParse(text);
    if (value == null) return 'Usá solo números';
    final (min, max) = _selectedType.customAmountRange!;
    if (value < min) return 'El mínimo es ${formatCurrency(min)}';
    if (value > max) return 'El máximo es ${formatCurrency(max)}';
    return null;
  }

  /// The amount that would actually be charged, or `null` while it can't
  /// be resolved yet (missing/invalid custom amount).
  double? get _resolvedAmount {
    if (!_isCustomAmount) return _selectedType.defaultAmount;
    if (_amountError != null) return null;
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  // Per design brief §2.6, the CTA's 3 states depend ONLY on the amount —
  // the phone is optional (an empty phone just changes the success
  // overlay's copy to "Lista para compartir por WhatsApp" instead of
  // "Enviada a {phone}", it never blocks the purchase itself).
  bool get _canSubmit => _resolvedAmount != null && !_isSubmitting;

  String get _ctaLabel {
    if (_isCustomAmount) {
      if (_amountController.text.trim().isEmpty) return 'Ingresá un monto';
      if (_amountError != null) return 'Corregí el monto';
    }
    final amount = _resolvedAmount;
    if (amount == null) return 'Ingresá un monto';
    return 'Comprar y enviar ${formatCurrency(amount)}';
  }

  void _selectTier(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (!_carouselController.hasClients) return;
    final viewport = _carouselController.position.viewportDimension;
    final target = (index * _cardExtent) - (viewport - _cardWidth) / 2;
    final maxScroll = _carouselController.position.maxScrollExtent;
    _carouselController.animateTo(
      target.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    final amount = _resolvedAmount!;
    final phone = _phoneController.text.trim();
    final type = _selectedType;
    final message = _messageController.text.trim();

    if (ref.read(connectionModeProvider) == ConnectionMode.remote) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
      try {
        await ref
            .read(dataSourceProvider)
            .createGift(
              type: type,
              amount: amount,
              recipientPhone: phone,
              message: message.isEmpty ? null : message,
            );
      } on DioException catch (error) {
        if (!mounted) return;
        setState(() => _errorMessage = _remoteCreateGiftErrorMessage(error));
        return;
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _errorMessage = 'No pudimos conectarnos. Revisá tu conexión.',
        );
        return;
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      if (!mounted) return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xE60E0F16),
      builder: (dialogContext) => _GiftSuccessOverlay(
        type: type,
        amount: amount,
        phone: phone,
        onDone: () {
          Navigator.of(dialogContext).pop();
          _resetForm();
        },
      ),
    );
  }

  /// Reads the backend's `{"errors": {...}}` body on a 422 (per the
  /// confirmed `POST /gifts` contract) into a single line; falls back to a
  /// generic connectivity message for anything else — same shape as
  /// `my_places_screen.dart`'s `_remoteLoginErrorMessage`.
  String _remoteCreateGiftErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        return errors.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', ');
      }
    }
    return 'No pudimos conectarnos. Revisá tu conexión.';
  }

  void _resetForm() {
    setState(() {
      _selectedIndex = 0;
      _amountController.clear();
      _phoneController.clear();
      _messageController.clear();
    });
    if (_carouselController.hasClients) {
      _carouselController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Regalar', style: AppTheme.headline),
              const SizedBox(height: 8),
              Text(
                'Elegí una gift card de Fudo para usar en cualquier local '
                'de la red.',
                style: AppTheme.bodySecondary,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                // A plain (non-lazy) horizontal scroll: only 4 small cards
                // ever exist, so there's no virtualization to gain and the
                // whole carousel stays simple to reason about (and to test).
                // Tapping a card selects it and smooth-scrolls it into view.
                child: SingleChildScrollView(
                  controller: _carouselController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < GiftType.values.length;
                        index++
                      )
                        Padding(
                          padding: const EdgeInsets.only(right: _cardSpacing),
                          child: GestureDetector(
                            key: ValueKey(
                              'giftTierTap_${GiftType.values[index].name}',
                            ),
                            onTap: () => _selectTier(index),
                            child: AnimatedScale(
                              scale: index == _selectedIndex ? 1 : 0.92,
                              duration: const Duration(milliseconds: 200),
                              child: _GiftTierCard(
                                type: GiftType.values[index],
                                selected: index == _selectedIndex,
                                sheen: _sheenController,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < GiftType.values.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _selectedIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _selectedIndex
                            ? AppTheme.accent
                            : AppTheme.textTertiary,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                    ),
                ],
              ),
              if (_isCustomAmount) ...[
                const SizedBox(height: 24),
                _CustomAmountField(
                  controller: _amountController,
                  error: _amountError,
                  range: _selectedType.customAmountRange!,
                ),
              ],
              if (!isLoggedIn) ...[
                const SizedBox(height: 22),
                _LoginRequiredCard(
                  key: const ValueKey('giftLoginRequiredCard'),
                  onLoginTap: () => context.go(AppRoutes.myPlaces),
                ),
              ] else ...[
                const SizedBox(height: 28),
                _SectionLabel('PARA QUIÉN'),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('giftPhoneField'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: AppTheme.body,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono del destinatario',
                    hintText: '+54 9 11 1234 5678',
                    prefixIcon: Icon(Symbols.smartphone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 2,
                  maxLines: 3,
                  style: AppTheme.body,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje (opcional)',
                    hintText: 'Escribí una dedicatoria corta…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 28),
                _GiftCtaButton(
                  key: const ValueKey('giftCtaButton'),
                  label: _isSubmitting ? 'Enviando…' : _ctaLabel,
                  enabled: _canSubmit,
                  onTap: _handleSubmit,
                  sheen: _sheenController,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    key: const ValueKey('giftErrorMessage'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Iniciá sesión para comprar" gate — analogous to
/// `web/components/features/regalar/LoginRequiredCard.tsx`. Replaces the
/// checkout fields (phone/message/CTA) while [isLoggedInProvider] is
/// `false`; the tier tiles above stay visible either way, matching the web
/// reference's "anyone can browse, buying needs a session" behavior.
class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard({super.key, required this.onLoginTap});

  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.priceChipBackground,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Symbols.lock, color: AppTheme.accent, size: 21),
            ),
            const SizedBox(height: 14),
            Text(
              'Iniciá sesión para comprar',
              style: AppTheme.title.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Podés ver todas las tarjetas y sus beneficios. Para enviar '
              'una gift card necesitás una cuenta.',
              style: AppTheme.bodySecondary,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('giftLoginRequiredButton'),
                onPressed: onLoginTap,
                child: const Text('Iniciar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase "eyebrow" label (e.g. "PARA QUIÉN") matching the design's
/// tertiary-color, letter-spaced section headers.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.body.copyWith(
        color: AppTheme.textTertiary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 1.1,
      ),
    );
  }
}

/// One gift card tier in the carousel, painted with its
/// [GiftTypePresentation.gradient]/[GiftTypePresentation.textColor].
class _GiftTierCard extends StatelessWidget {
  const _GiftTierCard({
    required this.type,
    required this.selected,
    required this.sheen,
  });

  final GiftType type;
  final bool selected;

  /// Shared 3.6s repeating controller driving the idle sheen sweep — see
  /// `_GiftingScreenState._sheenController`.
  final Animation<double> sheen;

  @override
  Widget build(BuildContext context) {
    final amount = type.defaultAmount;
    final textColor = type.textColor;

    return Container(
      width: 250,
      height: 190,
      decoration: BoxDecoration(
        gradient: type.gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
        border: selected
            ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
        child: Stack(
          children: [
            Positioned.fill(
              child: _SheenSweep(animation: sheen, widthFraction: 70 / 250),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type.name.toUpperCase(),
                        style: AppTheme.title.copyWith(
                          color: textColor,
                          letterSpacing: 1.5,
                          fontSize: 15,
                        ),
                      ),
                      if (selected)
                        Icon(
                          Symbols.check_circle,
                          color: textColor,
                          size: 22,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    amount != null ? formatCurrency(amount) : 'Monto libre',
                    style: AppTheme.headline.copyWith(
                      color: textColor,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type.perk,
                    style: AppTheme.body.copyWith(
                      color: textColor.withValues(alpha: textColor.a * 0.85),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// Custom-amount input shown only for tiers with a
/// [GiftTypePresentation.customAmountRange] (Platinum), with live validation
/// copy per `docs/design-brief.md` §2.6.
class _CustomAmountField extends StatelessWidget {
  const _CustomAmountField({
    required this.controller,
    required this.error,
    required this.range,
  });

  final TextEditingController controller;
  final String? error;
  final (double min, double max) range;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('MONTO PERSONALIZADO'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('giftCustomAmountField'),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(),
          style: AppTheme.title,
          decoration: InputDecoration(
            prefixText: r'$ ',
            prefixStyle: AppTheme.title,
            hintText: 'Ej: 150000',
            errorText: error,
            helperText: error == null
                ? 'Entre ${formatCurrency(range.$1)} y '
                      '${formatCurrency(range.$2)}'
                : null,
            helperStyle: AppTheme.body.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient CTA button, built as a custom widget per the comment on
/// `AppTheme.ctaGradient` (a flat `ButtonStyle` can't paint a gradient).
class _GiftCtaButton extends StatelessWidget {
  const _GiftCtaButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.sheen,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// Shared 3.6s repeating controller driving the idle sheen sweep — only
  /// shown while [enabled], matching the web reference's `canPay ? ... :
  /// null` gate on the sweep (`GiftCheckoutForm.tsx`). The sweep band is
  /// sized to a third of the button (same as the web reference's `w-1/3`
  /// strip) but its translateX range still carries it edge to edge, so the
  /// visible sweep reaches the full width of the button rather than
  /// stopping partway across.
  final Animation<double> sheen;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.ctaGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.38),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Stack(
            children: [
              if (enabled)
                Positioned.fill(
                  child: _SheenSweep(animation: sheen, widthFraction: 1 / 3),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  onTap: enabled ? onTap : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        label,
                        style: AppTheme.button.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The idle shimmer/sheen sweep used on the gift tier cards and the CTA
/// button — a straight port of the web reference's `fudoSheen` keyframe
/// (`web/app/globals.css`): translateX(-120% -> 320%) of the sweep band's
/// own width over the first 60% of the loop, with opacity fading in over
/// 0-15% and back out over 55-60% so the loop restart never reads as an
/// abrupt jump, then staying invisible for the remaining 40% of the cycle.
/// Driven by a shared [Animation] (`_GiftingScreenState._sheenController`,
/// 3.6s repeating) so every card and the button sweep in lockstep, matching
/// the web reference's shared `[animation-duration:3.6s]` override.
class _SheenSweep extends StatelessWidget {
  const _SheenSweep({required this.animation, required this.widthFraction});

  final Animation<double> animation;

  /// Width of the sweep band as a fraction of the parent's width — 70px of
  /// a 250px card in the web reference, or a third of the button.
  final double widthFraction;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final opacity = _opacityAt(t);
          if (opacity <= 0) return const SizedBox.shrink();
          final progress = (t / 0.6).clamp(0.0, 1.0);
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFraction,
            child: FractionalTranslation(
              // -120% at progress 0 to 320% at progress 1, relative to the
              // sweep band's own width — same as the CSS keyframe.
              translation: Offset(-1.2 + progress * 4.4, 0),
              child: Opacity(
                opacity: opacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x52FFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _opacityAt(double t) {
    if (t < 0.15) return t / 0.15;
    if (t <= 0.55) return 1;
    if (t <= 0.60) return 1 - (t - 0.55) / 0.05;
    return 0;
  }
}

/// Success overlay shown after "buying" a gift card: two expanding rings,
/// simulated confetti, the winning tier card and a stamp-in headline —
/// matching `fudoRing`/`fudoConfetti`/`fudoStamp` in `docs/design-brief.md`.
///
/// No real payment happens (there's no gateway/backend yet) — this purely
/// celebrates the local, in-memory "purchase".
class _GiftSuccessOverlay extends StatefulWidget {
  const _GiftSuccessOverlay({
    required this.type,
    required this.amount,
    required this.phone,
    required this.onDone,
  });

  final GiftType type;
  final double amount;
  final String phone;
  final VoidCallback onDone;

  @override
  State<_GiftSuccessOverlay> createState() => _GiftSuccessOverlayState();
}

class _GiftSuccessOverlayState extends State<_GiftSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  static const _confettiColors = [
    AppTheme.accent,
    Color(0xFFE0B95C),
    AppTheme.rewardGreen,
    Color(0xFF6E5AC8),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    final random = math.Random();
    _particles = List.generate(18, (i) {
      return _ConfettiParticle(
        angle: random.nextDouble() * 2 * math.pi,
        distance: 90 + random.nextDouble() * 90,
        size: 5 + random.nextDouble() * 5,
        color: _confettiColors[random.nextInt(_confettiColors.length)],
        delay: random.nextDouble() * 0.25,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: _controller,
        // NOTE: `_buildCard` is built inline here (not passed as
        // `AnimatedBuilder.child`) on purpose. `child:` is only built once
        // and reused across every tick — but `_buildCard` reads the
        // animation's current value to drive its own elastic scale-in and
        // the delayed "¡Gift card enviada!" stamp fade-in, so it needs a
        // fresh rebuild every frame. Passing it as `child:` previously froze
        // it at its very first frame (t≈0: 60% scale, invisible headline)
        // forever — the rings/confetti still played and faded correctly, so
        // the end state looked like a small, plain, title-less card with no
        // celebration at all, matching the reported screenshot exactly.
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [..._buildRings(t), ..._buildConfetti(t), _buildCard(context, t)],
          );
        },
      ),
    );
  }

  List<Widget> _buildRings(double t) {
    return [0.0, 0.25].map((delay) {
      final ringT = _delayed(t, delay, 0.75);
      return Opacity(
        opacity: (1 - ringT).clamp(0, 1),
        child: Container(
          width: 160 + ringT * 220,
          height: 160 + ringT * 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.type.textColor.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildConfetti(double t) {
    return _particles.map((particle) {
      final localT = _delayed(t, particle.delay, 1 - particle.delay);
      final eased = Curves.easeOut.transform(localT);
      final dx = math.cos(particle.angle) * particle.distance * eased;
      final dy =
          math.sin(particle.angle) * particle.distance * eased +
          80 * eased * eased;
      return Opacity(
        opacity: (1 - localT).clamp(0, 1),
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: eased * math.pi * particle.angle,
            child: Container(
              width: particle.size,
              height: particle.size,
              decoration: BoxDecoration(
                color: particle.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCard(BuildContext context, double t) {
    final cardT = Curves.elasticOut.transform(_delayed(t, 0.1, 0.6));
    final stampT = _delayed(t, 0.45, 0.4).clamp(0, 1);

    return Transform.scale(
      scale: 0.6 + 0.4 * cardT.clamp(0.0, 1.4),
      child: Container(
        width: 280,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadow,
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: stampT.toDouble(),
              child: Transform.scale(
                scale: 0.7 + 0.3 * stampT,
                child: Text(
                  '¡Gift card enviada!',
                  textAlign: TextAlign.center,
                  style: AppTheme.headline.copyWith(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: widget.type.gradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusHero),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.type.name.toUpperCase(),
                    style: AppTheme.title.copyWith(
                      color: widget.type.textColor,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency(widget.amount),
                    style: AppTheme.headline.copyWith(
                      color: widget.type.textColor,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.phone.isEmpty
                  ? 'Lista para compartir por WhatsApp'
                  : 'Enviada a ${widget.phone}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySecondary,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onDone,
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _delayed(double t, double delay, double span) {
    if (span <= 0) return t >= delay ? 1 : 0;
    return ((t - delay) / span).clamp(0.0, 1.0);
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.delay,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double delay;
}
