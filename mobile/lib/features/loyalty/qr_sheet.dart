import 'package:flutter/material.dart';
// `flutter_riverpod` exports its own `Consumer` widget, which clashes with
// our domain `Consumer` model (`data/models/consumer.dart`) — this widget
// only needs `ConsumerStatefulWidget`/`ConsumerState`/`AsyncValue`, so hide
// the widget instead of aliasing the domain model everywhere below.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/consumer.dart';
import '../../data/providers.dart';

/// Which tab of [LoyaltyQrSheet] should be selected when it opens.
enum LoyaltyQrTab { miQr, escanear }

/// Bottom sheet for the loyalty QR flow (design brief §2.8): a "Mi QR" tab
/// that shows the consumer's own scannable code, and an "Escanear" tab that
/// opens the device camera to scan a merchant's QR.
///
/// Reusable: meant to be shown via `showModalBottomSheet(builder: (_) =>
/// const LoyaltyQrSheet())` from the bottom nav's central QR action, or from
/// the restaurant detail screen — this widget does not invoke itself.
class LoyaltyQrSheet extends ConsumerStatefulWidget {
  const LoyaltyQrSheet({super.key, this.initialTab = LoyaltyQrTab.miQr});

  /// Tab selected on first build. Lets callers deep-link straight into
  /// "Escanear" (e.g. a "Scan to check in" shortcut) instead of always
  /// landing on "Mi QR".
  final LoyaltyQrTab initialTab;

  @override
  ConsumerState<LoyaltyQrSheet> createState() => _LoyaltyQrSheetState();
}

class _LoyaltyQrSheetState extends ConsumerState<LoyaltyQrSheet>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  /// Drives the vertical sweep of the scan line (`fudoScan` in the design,
  /// 2.4s loop). `repeat(reverse: true)` gives the up-down loop cheaply
  /// without hand-rolling a ping-pong tween.
  late final AnimationController _scanLineController;

  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == LoyaltyQrTab.escanear ? 1 : 0,
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  /// Lazily created so the camera is never touched by the "Mi QR" tab.
  MobileScannerController get _scanner =>
      _scannerController ??= MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
      );

  @override
  void dispose() {
    _tabController.dispose();
    _scanLineController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Código escaneado (demo)')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusBottomSheetTop),
          topRight: Radius.circular(AppTheme.radiusBottomSheetTop),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: SizedBox(
            height: mediaQuery.size.height * 0.75,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Tu código Fudo', style: AppTheme.headline),
                const SizedBox(height: 16),
                _QrTabBar(controller: _tabController),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _MiQrTab(consumer: ref.watch(currentConsumerProvider)),
                      _EscanearTab(
                        controller: _scanner,
                        scanLineController: _scanLineController,
                        onDetect: _onDetect,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mi QR" / "Escanear" segmented control, styled with [AppTheme] instead of
/// Material's default underline `TabBar` look.
class _QrTabBar extends StatelessWidget {
  const _QrTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          splashBorderRadius: BorderRadius.circular(AppTheme.radiusPill),
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: AppTheme.button,
          unselectedLabelStyle: AppTheme.button,
          tabs: const [
            Tab(text: 'Mi QR'),
            Tab(text: 'Escanear'),
          ],
        ),
      ),
    );
  }
}

/// "Mi QR" tab: a real QR code (via `qr_flutter`) encoding the demo
/// consumer's id, plus the copy and `ID {qrId}` badge from the design brief.
class _MiQrTab extends StatelessWidget {
  const _MiQrTab({required this.consumer});

  final AsyncValue<Consumer> consumer;

  /// Deterministic, human-friendly id derived from the consumer's uuid —
  /// there is no backend-issued "loyalty QR id" field on `consumers` yet, so
  /// this is a presentation-only stand-in (design brief §2.8/§2.7 both just
  /// say "badge `ID {qrId}`").
  static String _qrIdFor(String consumerId) =>
      consumerId.replaceAll('-', '').toUpperCase().substring(0, 8);

  @override
  Widget build(BuildContext context) {
    return consumer.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
      error: (error, stackTrace) => Center(
        child: Text(
          'No pudimos cargar tu código. Probá de nuevo más tarde.',
          style: AppTheme.bodySecondary,
          textAlign: TextAlign.center,
        ),
      ),
      data: (data) {
        final consumerId = data.id;
        final qrId = _qrIdFor(consumerId);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusHero),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTheme.shadow,
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: QrImageView(
                    data: 'fudo:loyalty:$consumerId',
                    version: QrVersions.auto,
                    size: 200,
                    padding: EdgeInsets.zero,
                    gapless: true,
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppTheme.backgroundOuter,
                    ),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppTheme.backgroundOuter,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mostrale este código al mesero para validar tu visita.',
                style: AppTheme.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    'ID $qrId',
                    style: AppTheme.body.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Escanear" tab: live camera preview with an orange scan reticle and an
/// animated sweep line (`fudoScan`, 2.4s loop) overlaid on top.
class _EscanearTab extends StatelessWidget {
  const _EscanearTab({
    required this.controller,
    required this.scanLineController,
    required this.onDetect,
  });

  final MobileScannerController controller;
  final AnimationController scanLineController;
  final void Function(BarcodeCapture capture) onDetect;

  static const double _windowSize = 220;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
              child: MobileScanner(
                controller: controller,
                fit: BoxFit.cover,
                onDetect: onDetect,
                placeholderBuilder: (context) => const ColoredBox(
                  color: AppTheme.backgroundOuter,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                ),
                errorBuilder: (context, error) =>
                    _ScannerErrorView(error: error),
                overlayBuilder: (context, constraints) => Center(
                  child: SizedBox(
                    width: _windowSize,
                    height: _windowSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const _ScanReticle(size: _windowSize),
                        AnimatedBuilder(
                          animation: scanLineController,
                          builder: (context, _) {
                            final top =
                                scanLineController.value *
                                (_windowSize - 3);
                            return Positioned(
                              top: top,
                              left: 6,
                              right: 6,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                'Escaneá el QR del local',
                style: AppTheme.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Se suma la visita y aplicamos tu descuento al instante.',
                style: AppTheme.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Four orange corner brackets around the scan area — cheaper than a
/// `CustomPainter` for a shape this simple, and keeps the "mira" look from
/// the design without a full-rectangle border competing with the sweep line.
class _ScanReticle extends StatelessWidget {
  const _ScanReticle({required this.size});

  final double size;

  static const double _cornerLength = 28;
  static const double _strokeWidth = 3;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppTheme.accent, width: _strokeWidth);

    Widget corner({required bool top, required bool left}) {
      return Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: Container(
          width: _cornerLength,
          height: _cornerLength,
          decoration: BoxDecoration(
            border: Border(
              top: top ? side : BorderSide.none,
              bottom: top ? BorderSide.none : side,
              left: left ? side : BorderSide.none,
              right: left ? BorderSide.none : side,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          corner(top: true, left: true),
          corner(top: true, left: false),
          corner(top: false, left: true),
          corner(top: false, left: false),
        ],
      ),
    );
  }
}

/// Shown by `MobileScanner.errorBuilder` when the camera fails to start —
/// most commonly a denied camera permission.
class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: AppTheme.backgroundOuter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: AppTheme.textTertiary,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                isPermissionDenied
                    ? 'No tenemos permiso para usar la cámara. '
                          'Habilitalo desde los ajustes del dispositivo '
                          'para escanear el código.'
                    : 'No pudimos abrir la cámara. Probá de nuevo en un momento.',
                style: AppTheme.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
