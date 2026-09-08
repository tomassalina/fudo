import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting/currency_format.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/business_hour.dart';
import '../../data/models/loyalty_rule.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/merchant.dart';
import '../../data/models/visit_summary.dart';
import '../../data/providers.dart';
import '../loyalty/qr_sheet.dart';
import 'widgets/search_utils.dart' show merchantTypeLabel;

/// Restaurant detail screen (`docs/design-brief.md` §2.5, backlog item 7):
/// full-width photo header with back/favorite buttons, name/meta/address,
/// an hours accordion ("Abierto ahora"/"Cerrado"), WhatsApp/Delivery
/// deep-links, and "Mis visitas" (loyalty)/"Menú" sub-tabs.
class RestaurantDetailScreen extends ConsumerStatefulWidget {
  const RestaurantDetailScreen({required this.merchantId, super.key});

  final int merchantId;

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantAsync = ref.watch(merchantProvider(widget.merchantId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: merchantAsync.when(
        data: (merchant) {
          if (merchant == null) {
            return const _MessageBody(text: 'Restaurante no encontrado');
          }
          return _DetailBody(merchant: merchant, tabController: _tabController);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (error, stackTrace) =>
            const _MessageBody(text: 'No pudimos cargar este lugar.'),
      ),
    );
  }
}

/// Shared shell for the "merchant not found"/"failed to load" states: still
/// navigable via a back button instead of leaving the user stranded.
class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Symbols.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  text,
                  style: AppTheme.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The screen's real content, once [merchantProvider] resolves.
class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.merchant, required this.tabController});

  final Merchant merchant;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final isFavorite = favoriteIds.contains(merchant.id);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _PhotoHeader(
            merchant: merchant,
            isFavorite: isFavorite,
            onToggleFavorite: () =>
                ref.read(favoriteIdsProvider.notifier).toggle(merchant.id),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _MerchantInfo(merchant: merchant),
              const SizedBox(height: 20),
              _HoursAccordion(merchantId: merchant.id),
              const SizedBox(height: 16),
              _ActionButtonsRow(merchant: merchant),
              const SizedBox(height: 28),
              _DetailTabBar(controller: tabController),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: tabController,
                builder: (context, _) => tabController.index == 0
                    ? _LoyaltyTab(merchantId: merchant.id)
                    : _MenuTab(merchantId: merchant.id),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Photo header
// ---------------------------------------------------------------------

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.merchant,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final Merchant merchant;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final imageUrl = merchant.coverImageUrl;

    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _placeholder(),
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            )
          else
            _placeholder(),
          // Dark gradient overlay so the floating buttons stay legible over
          // any photo, regardless of its own colors/brightness.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Color(0xCC0E0F16),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: Symbols.arrow_back,
                    onTap: () => context.pop(),
                  ),
                  _CircleIconButton(
                    icon: isFavorite
                        ? Symbols.favorite
                        : Symbols.favorite_border,
                    iconColor: isFavorite ? AppTheme.accent : Colors.white,
                    iconFill: isFavorite ? 1 : 0,
                    onTap: onToggleFavorite,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final type = merchant.type;
    return DecoratedBox(
      decoration: BoxDecoration(color: type.color.withValues(alpha: 0.22)),
      child: Center(child: Icon(type.icon, color: type.color, size: 56)),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
    this.iconFill = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final double iconFill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: iconColor, size: 22, fill: iconFill),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Name / meta / address
// ---------------------------------------------------------------------

class _MerchantInfo extends StatelessWidget {
  const _MerchantInfo({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final type = merchant.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(merchant.name, style: AppTheme.headline),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(type.icon, size: 16, color: type.color),
            const SizedBox(width: 6),
            Text(merchantTypeLabel(type), style: AppTheme.bodySecondary),
            if (merchant.neighborhood != null) ...[
              const SizedBox(width: 10),
              const Icon(
                Symbols.location_on,
                size: 14,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(merchant.neighborhood!, style: AppTheme.bodySecondary),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Symbols.pin_drop,
                size: 14,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(merchant.address, style: AppTheme.bodySecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Hours accordion
// ---------------------------------------------------------------------

const List<DayOfWeek> _weekOrder = [
  DayOfWeek.monday,
  DayOfWeek.tuesday,
  DayOfWeek.wednesday,
  DayOfWeek.thursday,
  DayOfWeek.friday,
  DayOfWeek.saturday,
  DayOfWeek.sunday,
];

const Map<DayOfWeek, String> _dayLabels = {
  DayOfWeek.monday: 'Lunes',
  DayOfWeek.tuesday: 'Martes',
  DayOfWeek.wednesday: 'Miércoles',
  DayOfWeek.thursday: 'Jueves',
  DayOfWeek.friday: 'Viernes',
  DayOfWeek.saturday: 'Sábado',
  DayOfWeek.sunday: 'Domingo',
};

int? _parseMinutes(String? hhmmss) {
  if (hhmmss == null) return null;
  final parts = hhmmss.split(':');
  if (parts.length < 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  return hours * 60 + minutes;
}

String _formatHHmm(String? hhmmss) {
  if (hhmmss == null || hhmmss.length < 5) return '--:--';
  return hhmmss.substring(0, 5);
}

String _formatRange(BusinessHour hour) =>
    '${_formatHHmm(hour.opensAt)}–${_formatHHmm(hour.closesAt)}';

class _OpenStatus {
  const _OpenStatus({required this.isOpen, required this.todayHours});

  final bool isOpen;
  final List<BusinessHour> todayHours;
}

/// Computes whether the merchant is open right now, comparing the device's
/// real wall-clock time (`DateTime.now()`) against today's `business_hours`
/// rows. A merchant can have more than one row for the same day ("doble
/// turno") — every non-closed row for today is checked, not just the first.
///
/// Design decision: `closes_at == "00:00:00"` is read as "open until the end
/// of today" (minute 1440), not as "wraps into an early-morning shift
/// tomorrow" — that's the natural reading of every row in the fixtures (e.g.
/// Saturday 12:00–00:00 means "closes at midnight", not "closes at 00:00
/// tomorrow and reopens then too"). A row that genuinely spans past midnight
/// with a non-zero closing time (e.g. opens 22:00, closes 02:00) is still
/// handled correctly: it's looked up as *yesterday's* row when checking
/// whether we're still inside an overnight shift early this morning.
_OpenStatus _computeOpenStatus(List<BusinessHour> hours, DateTime now) {
  final today = _weekOrder[now.weekday - 1];
  final yesterday = _weekOrder[(now.weekday - 2 + 7) % 7];
  final nowMinutes = now.hour * 60 + now.minute;

  final todayHours = hours.where((h) => h.dayOfWeek == today).toList();
  final yesterdayHours = hours.where((h) => h.dayOfWeek == yesterday).toList();

  for (final hour in todayHours) {
    if (hour.closed) continue;
    final opens = _parseMinutes(hour.opensAt);
    final closes = _parseMinutes(hour.closesAt);
    if (opens == null || closes == null) continue;
    final effectiveCloses = closes <= opens ? 1440 : closes;
    if (nowMinutes >= opens && nowMinutes < effectiveCloses) {
      return _OpenStatus(isOpen: true, todayHours: todayHours);
    }
  }

  for (final hour in yesterdayHours) {
    if (hour.closed) continue;
    final opens = _parseMinutes(hour.opensAt);
    final closes = _parseMinutes(hour.closesAt);
    if (opens == null || closes == null) continue;
    final wrapsPastMidnight = closes > 0 && closes <= opens;
    if (wrapsPastMidnight && nowMinutes < closes) {
      return _OpenStatus(isOpen: true, todayHours: todayHours);
    }
  }

  return _OpenStatus(isOpen: false, todayHours: todayHours);
}

class _HoursAccordion extends ConsumerWidget {
  const _HoursAccordion({required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoursAsync = ref.watch(businessHoursProvider(merchantId));

    return hoursAsync.when(
      data: (hours) => _HoursAccordionBody(hours: hours),
      loading: () => const _HoursStatusCard(
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(width: 12),
            _HoursStatusText('Cargando horarios…'),
          ],
        ),
      ),
      error: (error, stackTrace) => const _HoursStatusCard(
        child: _HoursStatusText('No pudimos cargar los horarios.'),
      ),
    );
  }
}

class _HoursStatusText extends StatelessWidget {
  const _HoursStatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTheme.bodySecondary);
}

class _HoursStatusCard extends StatelessWidget {
  const _HoursStatusCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _HoursAccordionBody extends StatefulWidget {
  const _HoursAccordionBody({required this.hours});

  final List<BusinessHour> hours;

  @override
  State<_HoursAccordionBody> createState() => _HoursAccordionBodyState();
}

class _HoursAccordionBodyState extends State<_HoursAccordionBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = _computeOpenStatus(widget.hours, now);
    final today = _weekOrder[now.weekday - 1];
    final openRangesToday = status.todayHours.where((h) => !h.closed).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Symbols.schedule,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.isOpen ? 'Abierto ahora' : 'Cerrado',
                          style: AppTheme.title.copyWith(
                            fontSize: 15,
                            color: status.isOpen
                                ? AppTheme.rewardGreen
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (openRangesToday.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            openRangesToday.map(_formatRange).join(' y '),
                            style: AppTheme.bodySecondary.copyWith(
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Symbols.expand_more,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  for (final day in _weekOrder)
                    _DayRow(
                      label: _dayLabels[day]!,
                      hours: widget.hours
                          .where((h) => h.dayOfWeek == day && !h.closed)
                          .toList(),
                      isToday: day == today,
                    ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.hours,
    required this.isToday,
  });

  final String label;
  final List<BusinessHour> hours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final textColor = isToday ? AppTheme.textPrimary : AppTheme.textSecondary;
    final valueText = hours.isEmpty
        ? 'Cerrado'
        : hours.map(_formatRange).join(' y ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Text(
            valueText,
            style: AppTheme.body.copyWith(fontSize: 12.5, color: textColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// WhatsApp / Delivery actions
// ---------------------------------------------------------------------

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final whatsapp = merchant.whatsappNumber;
    final delivery = merchant.deliveryUrl;
    if (whatsapp == null && delivery == null) return const SizedBox.shrink();

    return Row(
      children: [
        if (whatsapp != null)
          Expanded(child: _WhatsAppButton(whatsappNumber: whatsapp)),
        if (whatsapp != null && delivery != null) const SizedBox(width: 10),
        if (delivery != null)
          Expanded(child: _DeliveryButton(deliveryUrl: delivery)),
      ],
    );
  }
}

/// Strips everything but digits from [whatsappNumber] and opens
/// `https://wa.me/{digits}`, per `docs/design-brief.md` §2.5/§3.
Future<void> _launchIfPossible(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton({required this.whatsappNumber});

  final String whatsappNumber;

  @override
  Widget build(BuildContext context) {
    final digits = whatsappNumber.replaceAll(RegExp('[^0-9]'), '');
    return OutlinedButton.icon(
      onPressed: () => _launchIfPossible(Uri.parse('https://wa.me/$digits')),
      icon: const Icon(Symbols.chat, size: 18),
      label: const Text('WhatsApp'),
    );
  }
}

class _DeliveryButton extends StatelessWidget {
  const _DeliveryButton({required this.deliveryUrl});

  final String deliveryUrl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.ctaGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          onTap: () => _launchIfPossible(Uri.parse(deliveryUrl)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Symbols.delivery_dining,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Delivery',
                  style: AppTheme.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// "Mis visitas" / "Menú" sub-tabs
// ---------------------------------------------------------------------

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          Tab(text: 'Mis visitas'),
          Tab(text: 'Menú'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// "Mis visitas" tab (loyalty)
// ---------------------------------------------------------------------

class _LoyaltyTierInfo {
  const _LoyaltyTierInfo({
    required this.label,
    required this.gradient,
    required this.textColor,
  });

  final String label;
  final Gradient gradient;
  final Color textColor;
}

// Gradients replicate `TIERS_L` from `docs/design-reference/Fudo App.dc.html`
// (also transcribed in `docs/design-brief.md` §1). Two of them are pixel
// identical to `GiftTypePresentation` entries in `data/models/gift.dart`
// (Cliente fijo == Platinum, Nivel Oro == Gold) — that's a coincidence in the
// source design, not a reason to couple the two enums together, so they're
// kept as independent constants here.
const _clienteFijoGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF1B1533), Color(0xFF3A2A78), Color(0xFF6E5AC8)],
  stops: [0, 0.48, 1],
);
const _nivelOroGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF3B2A14), Color(0xFF7A5A1F), Color(0xFFE0B95C)],
  stops: [0, 0.45, 1],
);
const _nivelPlataGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF1B1C2A), Color(0xFF33364B), Color(0xFF5A5F7D)],
  stops: [0, 0.55, 1],
);
const _nivelBronceGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF2A160E), Color(0xFF7A3A1C), Color(0xFFE8703A)],
  stops: [0, 0.55, 1],
);
const _sinVisitasGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1A1B26), Color(0xFF24263A)],
);

/// Loyalty tier for [visits] to THIS merchant, replicating `TIERS_L` from
/// the design brief §1 (capped at 10 visits, same as the progress bar).
_LoyaltyTierInfo _tierForVisits(int visits) {
  final capped = visits > 10 ? 10 : visits;
  if (capped >= 10) {
    return const _LoyaltyTierInfo(
      label: 'CLIENTE FIJO',
      gradient: _clienteFijoGradient,
      textColor: Color(0xFFD6CBFF),
    );
  }
  if (capped >= 8) {
    return const _LoyaltyTierInfo(
      label: 'NIVEL ORO',
      gradient: _nivelOroGradient,
      textColor: Color(0xFFFFE9AE),
    );
  }
  if (capped >= 4) {
    return const _LoyaltyTierInfo(
      label: 'NIVEL PLATA',
      gradient: _nivelPlataGradient,
      textColor: Color(0xFFDCE2F0),
    );
  }
  if (capped >= 1) {
    return const _LoyaltyTierInfo(
      label: 'NIVEL BRONCE',
      gradient: _nivelBronceGradient,
      textColor: Color(0xFFFFC7B0),
    );
  }
  return const _LoyaltyTierInfo(
    label: 'SIN VISITAS AÚN',
    gradient: _sinVisitasGradient,
    textColor: Color(0x99FFFFFF),
  );
}

/// Headline copy, exact strings per `docs/design-brief.md` §2.5/§3.
String _headlineFor({
  required int visits,
  required bool full,
  required LoyaltyRule? nextRule,
}) {
  if (full) return 'Sos cliente fijo';
  if (visits == 0) return 'Arrancá tu camino';
  final remaining = nextRule!.visitsRequired - visits;
  return remaining == 1
      ? 'Falta 1 visita para tu próximo premio'
      : 'Faltan $remaining visitas para tu próximo premio';
}

/// Secondary line under the headline — not mandated by the task's exact-copy
/// list, but present in the original prototype (`loyal.sub`) and cheap
/// fidelity to add now that [nextRule] is already at hand.
String _subFor({
  required int visits,
  required bool full,
  required LoyaltyRule? nextRule,
}) {
  if (full) return '5% de descuento en todas tus compras, siempre.';
  if (nextRule == null) return '';
  final remaining = nextRule.visitsRequired - visits;
  final visitPhrase = remaining == 1
      ? 'En tu próxima visita'
      : 'A la visita ${nextRule.visitsRequired}';
  if (nextRule.isPermanent) {
    return remaining == 1
        ? 'En tu próxima visita te convertís en cliente fijo: 5% siempre.'
        : 'A la visita ${nextRule.visitsRequired} te convertís en cliente fijo: 5% siempre.';
  }
  return '$visitPhrase: ${nextRule.rewardDescription}.';
}

class _LoyaltyTab extends ConsumerWidget {
  const _LoyaltyTab({required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(loyaltyRulesProvider(merchantId));
    final summariesAsync = ref.watch(visitSummariesProvider(merchantId));

    if (rulesAsync.isLoading || summariesAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }
    if (rulesAsync.hasError || summariesAsync.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No pudimos cargar tu fidelización.',
            style: AppTheme.bodySecondary,
          ),
        ),
      );
    }

    final rules = [...rulesAsync.requireValue]
      ..sort((a, b) => a.visitsRequired.compareTo(b.visitsRequired));
    final summaries = summariesAsync.requireValue;
    final visits = summaries.isEmpty ? 0 : _visitCount(summaries);

    return _LoyaltyContent(rules: rules, visits: visits);
  }

  /// `getVisitSummaries(merchantId: ...)` is already scoped to this merchant,
  /// so there should be at most one row — this just guards against the
  /// fixture ever containing more than one without crashing on `.single`.
  int _visitCount(List<VisitSummary> summaries) => summaries.first.count;
}

class _LoyaltyContent extends StatelessWidget {
  const _LoyaltyContent({required this.rules, required this.visits});

  final List<LoyaltyRule> rules;
  final int visits;

  @override
  Widget build(BuildContext context) {
    final nextIndex = rules.indexWhere((r) => r.visitsRequired > visits);
    final full = nextIndex == -1;
    final nextRule = full ? null : rules[nextIndex];
    final tier = _tierForVisits(visits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LoyaltyHero(
          tier: tier,
          visits: visits,
          headline: _headlineFor(
            visits: visits,
            full: full,
            nextRule: nextRule,
          ),
          sub: _subFor(visits: visits, full: full, nextRule: nextRule),
        ),
        if (rules.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Eyebrow('TU CAMINO EN ${tier.label}'),
          const SizedBox(height: 14),
          for (var i = 0; i < rules.length; i++)
            _LoyaltyStep(
              index: i + 1,
              rule: rules[i],
              done: visits >= rules[i].visitsRequired,
              isHere: visits == rules[i].visitsRequired,
              isNext: !full && i == nextIndex,
              isLast: i == rules.length - 1,
            ),
        ],
        const SizedBox(height: 8),
        const _ScanQrNote(),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppTheme.textTertiary,
      ),
    );
  }
}

class _LoyaltyHero extends StatelessWidget {
  const _LoyaltyHero({
    required this.tier,
    required this.visits,
    required this.headline,
    required this.sub,
  });

  final _LoyaltyTierInfo tier;
  final int visits;
  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final progress = visits.clamp(0, 10) / 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: tier.gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(
                    value: progress.toDouble(),
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$visits',
                        key: const ValueKey('loyaltyVisitsCount'),
                        style: AppTheme.headline.copyWith(
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'VISITAS',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: tier.textColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  headline,
                  style: AppTheme.headline.copyWith(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyStep extends StatelessWidget {
  const _LoyaltyStep({
    required this.index,
    required this.rule,
    required this.done,
    required this.isHere,
    required this.isNext,
    required this.isLast,
  });

  final int index;
  final LoyaltyRule rule;
  final bool done;
  final bool isHere;
  final bool isNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? AppTheme.accent
        : (isNext ? AppTheme.accent.withValues(alpha: 0.14) : AppTheme.surface);
    final dotBorderColor = done
        ? AppTheme.accent
        : (isNext ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border);
    final numColor = done
        ? Colors.white
        : (isNext ? AppTheme.priceChipText : AppTheme.textTertiary);
    final titleColor = done || isNext
        ? AppTheme.textPrimary
        : AppTheme.textSecondary;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      border: Border.all(color: dotBorderColor, width: 1.5),
                    ),
                    child: Text(
                      '$index',
                      style: AppTheme.title.copyWith(
                        fontSize: 12,
                        color: numColor,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 2),
                        color: done
                            ? AppTheme.accent.withValues(alpha: 0.5)
                            : AppTheme.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          rule.rewardDescription,
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          rule.rewardType.label,
                          style: AppTheme.body.copyWith(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isHere)
                    const _LoyaltyBadge(
                      label: 'ESTÁS ACÁ',
                      color: AppTheme.rewardGreen,
                      background: AppTheme.rewardGreenBackground,
                    )
                  else if (isNext)
                    const _LoyaltyBadge(
                      label: 'PRÓXIMO',
                      color: AppTheme.priceChipText,
                      background: AppTheme.priceChipBackground,
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

class _LoyaltyBadge extends StatelessWidget {
  const _LoyaltyBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Invites the user to scan the loyalty QR — tapping it opens the already
/// built `LoyaltyQrSheet` (design brief §2.8), reused as-is.
class _ScanQrNote extends StatelessWidget {
  const _ScanQrNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const LoyaltyQrSheet(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Symbols.qr_code_scanner,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Cada visita se suma escaneando el QR del local. '
                  'Tocá para mostrar tu código.',
                  style: AppTheme.bodySecondary.copyWith(fontSize: 12.5),
                ),
              ),
              const Icon(
                Symbols.chevron_right,
                color: AppTheme.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// "Menú" tab
// ---------------------------------------------------------------------

String _formatMenuItemPrice(MenuItem item) {
  final amount = formatThousands(item.price);
  return switch (item.currency) {
    Currency.ars => '\$$amount ARS',
    Currency.usd => 'US\$$amount',
  };
}

class _MenuTab extends ConsumerWidget {
  const _MenuTab({required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(menuItemsProvider(merchantId));

    return itemsAsync.when(
      data: (items) {
        final active = items.where((item) => item.active).toList();
        if (active.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Este local todavía no cargó su menú.',
                style: AppTheme.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Group by `section`, preserving the order sections first appear in
        // (not alphabetical) so it matches the order items were seeded in.
        final sections = <String, List<MenuItem>>{};
        for (final item in active) {
          sections.putIfAbsent(item.section ?? 'Otros', () => []).add(item);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in sections.entries) ...[
              _MenuSectionHeader(name: entry.key, count: entry.value.length),
              const SizedBox(height: 10),
              for (final item in entry.value) ...[
                _MenuItemCard(item: item),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No pudimos cargar el menú.',
            style: AppTheme.bodySecondary,
          ),
        ),
      ),
    );
  }
}

class _MenuSectionHeader extends StatelessWidget {
  const _MenuSectionHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Eyebrow(name.toUpperCase()),
        Text(
          '$count',
          style: AppTheme.body.copyWith(
            fontSize: 11.5,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  const _MenuItemCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsForMenuItemProvider(item.id));

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPhotoSmall),
            child: SizedBox(
              width: 70,
              height: 70,
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description!,
                    style: AppTheme.bodySecondary.copyWith(fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                tagsAsync.when(
                  data: (tags) => tags.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in tags) _DietTag(name: tag.name),
                            ],
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatMenuItemPrice(item),
                  style: AppTheme.title.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return const ColoredBox(
      color: AppTheme.surfaceSecondary,
      child: Icon(Symbols.restaurant, color: AppTheme.textTertiary),
    );
  }
}

class _DietTag extends StatelessWidget {
  const _DietTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.rewardGreenBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.rewardGreen,
        ),
      ),
    );
  }
}
