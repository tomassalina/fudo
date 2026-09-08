import 'dart:async';

import 'package:flutter/material.dart';
// `flutter_riverpod` exports its own `Consumer` widget, which clashes with
// our domain `Consumer` model (`data/models/consumer.dart`) — hide the
// widget instead of aliasing the domain model everywhere below (same
// convention as `features/loyalty/qr_sheet.dart`).
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/loyalty/loyalty_tier.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/consumer.dart';
import '../../data/models/consumer_settings.dart';
import '../../data/models/merchant.dart';
import '../../data/models/visit_summary.dart';
import '../../data/providers.dart';
import '../loyalty/qr_sheet.dart';
import '../search/widgets/search_utils.dart' show merchantTypeLabel;

// ---------------------------------------------------------------------
// Local, in-memory-only state
//
// None of the providers below touch `DataSource` — they model UI-only
// state the design brief explicitly scopes as fake/local for this MVP
// (§3 "Login: 100% fake", §5 item 9 "no hay backend para persistir el
// cambio"). They're `Notifier`s (not raw fields) so screens can `ref.watch`
// them and rebuild, following the same pattern as `FavoriteIdsNotifier` in
// `data/providers.dart`.
// ---------------------------------------------------------------------

/// Whether the demo user is "logged in". Starts `false`; tapping "Iniciar
/// sesión" flips it to `true` regardless of what (if anything) was typed
/// into the email/password fields — there is no backend to validate
/// against, matching the original prototype's `login()` handler exactly.
class _IsLoggedInNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void logIn() => state = true;

  void logOut() => state = false;
}

final _isLoggedInProvider = NotifierProvider<_IsLoggedInNotifier, bool>(
  _IsLoggedInNotifier.new,
);

/// In-memory overrides for the "DATOS PERSONALES" fields edited via the
/// sheet in Ajustes. There is no backend endpoint to persist these edits, so
/// a `null` field here means "show the real value from [Consumer]"; a
/// non-null field means "the user edited this in the current session" (lost
/// on hot restart or logout — never written back to any fixture/API).
@immutable
class _PersonalDataOverride {
  const _PersonalDataOverride({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
  });

  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
}

class _PersonalDataOverrideNotifier extends Notifier<_PersonalDataOverride> {
  @override
  _PersonalDataOverride build() => const _PersonalDataOverride();

  void save({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) {
    state = _PersonalDataOverride(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone.isEmpty ? null : phone,
    );
  }
}

final _personalDataOverrideProvider =
    NotifierProvider<_PersonalDataOverrideNotifier, _PersonalDataOverride>(
      _PersonalDataOverrideNotifier.new,
    );

/// Local-only override of the "tema claro/oscuro" switch in Ajustes. Seeded
/// from `consumerSettingsProvider.theme` the first time it resolves (same
/// seed-then-mutate shape as `FavoriteIdsNotifier`), then flipped directly
/// by the switch. Flipping it does **not** change the app's real theme yet
/// (`AppTheme.dark` stays hardcoded in `main.dart`, untouched by this
/// change) — the design brief scopes this as visual/local-only for now.
class _DarkThemeOverrideNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<AsyncValue<ConsumerSettings>>(consumerSettingsProvider, (
      previous,
      next,
    ) {
      final settings = next.value;
      if (settings == null) return;
      state = settings.theme == ThemePreference.dark;
    });
    final settings = ref.watch(consumerSettingsProvider).value;
    return settings?.theme == ThemePreference.dark;
  }

  void toggle() => state = !state;
}

final _isDarkThemeOverrideProvider =
    NotifierProvider<_DarkThemeOverrideNotifier, bool>(
      _DarkThemeOverrideNotifier.new,
    );

/// Local-only override of the "notificaciones" switch, seeded from
/// `consumerSettingsProvider.notificationsEnabled` the same way as
/// [_DarkThemeOverrideNotifier] — no backend write either.
class _NotificationsOverrideNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<AsyncValue<ConsumerSettings>>(consumerSettingsProvider, (
      previous,
      next,
    ) {
      final settings = next.value;
      if (settings == null) return;
      state = settings.notificationsEnabled;
    });
    return ref.watch(consumerSettingsProvider).value?.notificationsEnabled ??
        true;
  }

  void toggle() => state = !state;
}

final _notificationsOverrideProvider =
    NotifierProvider<_NotificationsOverrideNotifier, bool>(
      _NotificationsOverrideNotifier.new,
    );

// ---------------------------------------------------------------------
// Screen entry point
// ---------------------------------------------------------------------

/// "Mis Lugares" / Perfil screen (`docs/design-brief.md` §2.7, backlog item
/// 9): a fake email/password login gate, then a profile with Visitas /
/// Favoritos / Ajustes sub-tabs once "logged in".
class MyPlacesScreen extends ConsumerWidget {
  const MyPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(_isLoggedInProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: isLoggedIn ? const _LoggedInView() : const _LoggedOutView(),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Logged-out state: fake login form
// ---------------------------------------------------------------------

class _LoggedOutView extends ConsumerStatefulWidget {
  const _LoggedOutView();

  @override
  ConsumerState<_LoggedOutView> createState() => _LoggedOutViewState();
}

class _LoggedOutViewState extends ConsumerState<_LoggedOutView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMockSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.ctaGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.storefront,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text('Bienvenido', style: AppTheme.headline),
          const SizedBox(height: 8),
          Text(
            'Ingresá a tu cuenta de Fudo',
            style: AppTheme.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              // Decorative: per the design brief §2.7/§3, Google login has
              // no real backend integration (the `consumers` schema has no
              // OAuth columns at all) and is not implemented — this only
              // tells the user so instead of pretending to do something.
              onPressed: () => _showMockSnackBar(
                'Login con Google no disponible en este MVP',
              ),
              icon: const Icon(Symbols.g_mobiledata, size: 22),
              label: const Text('Continuar con Google'),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider(color: AppTheme.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('o con email', style: AppTheme.bodySecondary),
              ),
              const Expanded(child: Divider(color: AppTheme.border)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'tu@email.com'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Tu contraseña'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // 100% fake login (design brief §3): any value — or none —
              // logs in. No credential is ever checked against anything.
              onPressed: () => ref.read(_isLoggedInProvider.notifier).logIn(),
              child: const Text('Iniciar sesión'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                _showMockSnackBar('Registro no disponible en este MVP'),
            child: const Text('¿No tenés cuenta? Registrate'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Logged-in state: profile header + Visitas/Favoritos/Ajustes sub-tabs
// ---------------------------------------------------------------------

class _LoggedInView extends ConsumerStatefulWidget {
  const _LoggedInView();

  @override
  ConsumerState<_LoggedInView> createState() => _LoggedInViewState();
}

class _LoggedInViewState extends ConsumerState<_LoggedInView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openQrSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LoyaltyQrSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consumerAsync = ref.watch(currentConsumerProvider);
    final summariesAsync = ref.watch(visitSummariesProvider(null));
    final topTier = topLoyaltyTierForCounts(
      (summariesAsync.value ?? const <VisitSummary>[]).map((s) => s.count),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: consumerAsync.when(
            data: (consumer) => _ProfileHeader(
              consumer: consumer,
              topTier: topTier,
              onOpenQr: _openQrSheet,
            ),
            loading: () => const SizedBox(
              height: 72,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
            error: (error, stackTrace) => Text(
              'No pudimos cargar tu perfil.',
              style: AppTheme.bodySecondary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ProfilePillTabBar(controller: _tabController),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_VisitasTab(), _FavoritosTab(), _AjustesTab()],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.consumer,
    required this.topTier,
    required this.onOpenQr,
  });

  final Consumer consumer;
  final LoyaltyTier topTier;
  final VoidCallback onOpenQr;

  String get _initials {
    final first = consumer.firstName.isNotEmpty
        ? consumer.firstName[0]
        : '';
    final last = consumer.lastName.isNotEmpty ? consumer.lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.surfaceSecondary,
          child: Text(
            _initials,
            style: AppTheme.title.copyWith(color: AppTheme.textPrimary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${consumer.firstName} ${consumer.lastName}',
                style: AppTheme.title,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                consumer.email,
                style: AppTheme.bodySecondary,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _TierBadge(tier: topTier),
            ],
          ),
        ),
        IconButton(
          onPressed: onOpenQr,
          icon: const Icon(Symbols.qr_code_2, color: AppTheme.textPrimary),
          tooltip: 'Tu código Fudo',
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final LoyaltyTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: tier.gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        tier.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: tier.textColor,
        ),
      ),
    );
  }
}

class _ProfilePillTabBar extends StatelessWidget {
  const _ProfilePillTabBar({required this.controller});

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
          Tab(text: 'Visitas'),
          Tab(text: 'Favoritos'),
          Tab(text: 'Ajustes'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Shared small pieces (loading/error/empty states, section eyebrow)
// ---------------------------------------------------------------------

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

class _TabLoading extends StatelessWidget {
  const _TabLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent),
    );
  }
}

class _TabError extends StatelessWidget {
  const _TabError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: AppTheme.bodySecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textTertiary),
            const SizedBox(height: 14),
            Text(
              message,
              style: AppTheme.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// "Visitas" sub-tab
// ---------------------------------------------------------------------

class _VisitasTab extends ConsumerWidget {
  const _VisitasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(visitSummariesProvider(null));
    final merchantsAsync = ref.watch(merchantsProvider);

    if (summariesAsync.isLoading || merchantsAsync.isLoading) {
      return const _TabLoading();
    }
    if (summariesAsync.hasError || merchantsAsync.hasError) {
      return const _TabError(message: 'No pudimos cargar tus visitas.');
    }

    final merchantsById = {
      for (final merchant in merchantsAsync.requireValue) merchant.id: merchant,
    };
    final rows =
        <(VisitSummary, Merchant)>[
            for (final summary in summariesAsync.requireValue)
              if (merchantsById[summary.merchantId] case final merchant?)
                (summary, merchant),
          ]
          // Most recently visited first; summaries without a last-visit
          // date (shouldn't happen with real data, but the field is
          // nullable) sort last instead of crashing the comparator.
          ..sort((a, b) {
            final aDate = a.$1.lastVisitAt;
            final bDate = b.$1.lastVisitAt;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

    if (rows.isEmpty) {
      return const _EmptyTabState(
        icon: Symbols.storefront,
        message:
            'Todavía no visitaste ningún lugar. Escaneá el QR en tu '
            'próxima visita para empezar a sumar sellos.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const _Eyebrow('LUGARES QUE VISITASTE'),
        const SizedBox(height: 14),
        for (final (summary, merchant) in rows) ...[
          _VisitCard(summary: summary, merchant: merchant),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.summary, required this.merchant});

  final VisitSummary summary;
  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final tier = loyaltyTierForVisits(summary.count);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
        onTap: () =>
            context.push(AppRoutes.merchantDetail(merchant.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppTheme.radiusPhotoSmall,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: merchant.coverImageUrl != null
                      ? Image.network(
                          merchant.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _typePlaceholder(),
                        )
                      : _typePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.name,
                            style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TierBadge(tier: tier),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        merchantTypeLabel(merchant.type),
                        if (merchant.neighborhood != null)
                          merchant.neighborhood!,
                      ].join(' · '),
                      style: AppTheme.bodySecondary.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    _StampsRow(count: summary.count),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePlaceholder() {
    final type = merchant.type;
    return DecoratedBox(
      decoration: BoxDecoration(color: type.color.withValues(alpha: 0.22)),
      child: Center(child: Icon(type.icon, color: type.color, size: 24)),
    );
  }
}

/// One filled dot per visit, up to the design's 10-visit cap — a simple
/// stand-in for the prototype's `stamps(p, on)` grid (design brief §2.7,
/// task instructions).
class _StampsRow extends StatelessWidget {
  const _StampsRow({required this.count});

  final int count;

  static const int _max = 10;

  @override
  Widget build(BuildContext context) {
    final filled = count.clamp(0, _max);
    return Row(
      children: [
        for (var i = 0; i < _max; i++)
          Padding(
            padding: EdgeInsets.only(right: i == _max - 1 ? 0 : 5),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? AppTheme.accent : Colors.transparent,
                border: Border.all(
                  color: i < filled ? AppTheme.accent : AppTheme.border,
                  width: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// "Favoritos" sub-tab
// ---------------------------------------------------------------------

class _FavoritosTab extends ConsumerWidget {
  const _FavoritosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final merchantsAsync = ref.watch(merchantsProvider);

    if (merchantsAsync.isLoading) return const _TabLoading();
    if (merchantsAsync.hasError) {
      return const _TabError(message: 'No pudimos cargar tus favoritos.');
    }

    final favoriteMerchants = merchantsAsync.requireValue
        .where((merchant) => favoriteIds.contains(merchant.id))
        .toList();

    if (favoriteMerchants.isEmpty) {
      return const _EmptyTabState(
        icon: Symbols.favorite_border,
        message: 'Marcá lugares con el corazón y aparecen acá.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const _Eyebrow('TUS FAVORITOS'),
        const SizedBox(height: 14),
        for (final merchant in favoriteMerchants) ...[
          _FavoriteCard(
            merchant: merchant,
            onRemove: () =>
                ref.read(favoriteIdsProvider.notifier).toggle(merchant.id),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.merchant, required this.onRemove});

  final Merchant merchant;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
        onTap: () =>
            context.push(AppRoutes.merchantDetail(merchant.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppTheme.radiusPhotoSmall,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: merchant.coverImageUrl != null
                      ? Image.network(
                          merchant.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _typePlaceholder(),
                        )
                      : _typePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        merchantTypeLabel(merchant.type),
                        if (merchant.neighborhood != null)
                          merchant.neighborhood!,
                      ].join(' · '),
                      style: AppTheme.bodySecondary.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Symbols.favorite,
                  color: AppTheme.accent,
                  fill: 1,
                ),
                tooltip: 'Quitar de favoritos',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePlaceholder() {
    final type = merchant.type;
    return DecoratedBox(
      decoration: BoxDecoration(color: type.color.withValues(alpha: 0.22)),
      child: Center(child: Icon(type.icon, color: type.color, size: 24)),
    );
  }
}

// ---------------------------------------------------------------------
// "Ajustes" sub-tab
// ---------------------------------------------------------------------

class _AjustesTab extends ConsumerWidget {
  const _AjustesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumerAsync = ref.watch(currentConsumerProvider);
    final settingsAsync = ref.watch(consumerSettingsProvider);

    if (consumerAsync.isLoading || settingsAsync.isLoading) {
      return const _TabLoading();
    }
    if (consumerAsync.hasError || settingsAsync.hasError) {
      return const _TabError(message: 'No pudimos cargar tus ajustes.');
    }

    final consumer = consumerAsync.requireValue;
    final settings = settingsAsync.requireValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _PersonalDataSection(consumer: consumer),
        const SizedBox(height: 24),
        _PreferencesSection(consumer: consumer, settings: settings),
        const SizedBox(height: 24),
        const _SecuritySection(),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Eyebrow(title),
            ?action,
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
          ),
          child: Padding(padding: const EdgeInsets.all(6), child: child),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.body.copyWith(fontSize: 13.5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PersonalDataSection extends ConsumerWidget {
  const _PersonalDataSection({required this.consumer});

  final Consumer consumer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(_personalDataOverrideProvider);
    final firstName = override.firstName ?? consumer.firstName;
    final lastName = override.lastName ?? consumer.lastName;
    final email = override.email ?? consumer.email;
    final phone = override.phone ?? consumer.phone ?? '';

    return _SectionCard(
      title: 'DATOS PERSONALES',
      action: TextButton(
        onPressed: () => _showEditSheet(
          context,
          ref,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
        ),
        child: const Text('Editar'),
      ),
      child: Column(
        children: [
          _SettingsRow(
            label: 'Nombre',
            child: Text(firstName, style: AppTheme.bodySecondary),
          ),
          const Divider(color: AppTheme.border, height: 1),
          _SettingsRow(
            label: 'Apellido',
            child: Text(lastName, style: AppTheme.bodySecondary),
          ),
          const Divider(color: AppTheme.border, height: 1),
          _SettingsRow(
            label: 'Email',
            child: Text(email, style: AppTheme.bodySecondary),
          ),
          const Divider(color: AppTheme.border, height: 1),
          _SettingsRow(
            label: 'Teléfono',
            child: Text(
              phone.isEmpty ? '—' : phone,
              style: AppTheme.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref, {
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditPersonalDataSheet(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        onSave: (firstName, lastName, email, phone) {
          ref
              .read(_personalDataOverrideProvider.notifier)
              .save(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
              );
        },
      ),
    );
  }
}

/// Edits are held only in [_personalDataOverrideProvider] (in-memory, this
/// app session only) — there is no backend endpoint to persist a real
/// `consumers` update yet, per the task's explicit scoping.
class _EditPersonalDataSheet extends StatefulWidget {
  const _EditPersonalDataSheet({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.onSave,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final void Function(String firstName, String lastName, String email, String phone)
  onSave;

  @override
  State<_EditPersonalDataSheet> createState() =>
      _EditPersonalDataSheetState();
}

class _EditPersonalDataSheetState extends State<_EditPersonalDataSheet> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editar datos personales', style: AppTheme.title),
          const SizedBox(height: 16),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Apellido'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onSave(
                  _firstNameController.text.trim(),
                  _lastNameController.text.trim(),
                  _emailController.text.trim(),
                  _phoneController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection({required this.consumer, required this.settings});

  final Consumer consumer;
  final ConsumerSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(_isDarkThemeOverrideProvider);
    final notificationsEnabled = ref.watch(_notificationsOverrideProvider);

    return _SectionCard(
      title: 'PREFERENCIAS',
      child: Column(
        children: [
          _SettingsRow(
            label: 'Tema oscuro',
            child: Switch(
              value: isDark,
              onChanged: (_) =>
                  ref.read(_isDarkThemeOverrideProvider.notifier).toggle(),
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),
          _SettingsRow(
            label: 'Notificaciones',
            child: Switch(
              value: notificationsEnabled,
              onChanged: (_) => ref
                  .read(_notificationsOverrideProvider.notifier)
                  .toggle(),
            ),
          ),
          if (consumer.hasDniOnFile) ...[
            const Divider(color: AppTheme.border, height: 1),
            _SettingsRow(
              label: 'DNI',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.rewardGreenBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Symbols.verified_user,
                      size: 13,
                      color: AppTheme.rewardGreen,
                      fill: 1,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verificado y cifrado',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.rewardGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();

  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  bool _deleteArmed = false;
  Timer? _disarmTimer;

  @override
  void dispose() {
    _disarmTimer?.cancel();
    super.dispose();
  }

  void _armDelete() {
    setState(() => _deleteArmed = true);
    _disarmTimer?.cancel();
    _disarmTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _deleteArmed = false);
    });
  }

  void _onDeleteTap() {
    if (!_deleteArmed) {
      _armDelete();
      return;
    }
    _disarmTimer?.cancel();
    // No real account-deletion backend call exists — the design brief only
    // asks for the confirm-by-double-tap affordance, then returning to the
    // logged-out state (§2.7/§5 item 9). Unlike a plain "cerrar sesión",
    // deleting the account must also drop any in-memory edits (personal
    // data, theme/notification overrides) — otherwise logging back in as
    // the same demo consumer would resurrect a "ghost" of the supposedly
    // deleted account's edits (found by review).
    ref.invalidate(_personalDataOverrideProvider);
    ref.invalidate(_isDarkThemeOverrideProvider);
    ref.invalidate(_notificationsOverrideProvider);
    ref.read(_isLoggedInProvider.notifier).logOut();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'SEGURIDAD Y CUENTA',
      child: Column(
        children: [
          _AccountActionRow(
            icon: Symbols.lock_reset,
            label: 'Restablecer contraseña',
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Te enviaríamos un email para restablecer tu '
                      'contraseña (no disponible en este MVP).',
                    ),
                  ),
                );
            },
          ),
          const Divider(color: AppTheme.border, height: 1),
          _AccountActionRow(
            icon: Symbols.logout,
            label: 'Cerrar sesión',
            onTap: () => ref.read(_isLoggedInProvider.notifier).logOut(),
          ),
          const Divider(color: AppTheme.border, height: 1),
          _AccountActionRow(
            icon: Symbols.delete_forever,
            label: _deleteArmed
                ? 'Tocá de nuevo para confirmar'
                : 'Eliminar cuenta',
            danger: true,
            onTap: _onDeleteTap,
          ),
        ],
      ),
    );
  }
}

class _AccountActionRow extends StatelessWidget {
  const _AccountActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : AppTheme.textPrimary;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.body.copyWith(
                  fontSize: 13.5,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Symbols.chevron_right, size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
