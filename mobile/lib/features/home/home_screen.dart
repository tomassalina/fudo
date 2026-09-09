import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets/network_error_view.dart';
import 'widgets/featured_grid.dart';
import 'widgets/home_header.dart';

/// "Inicio" tab (`docs/flutter-vs-nextjs-gap-report.md`, "1. Inicio/Home",
/// Tarea 1) — the screen the gap report found missing entirely: a header
/// (logo + "Activar ubicación" pill) and a "Lugares destacados" grid,
/// analogous to `web/app/(marketing)/page.tsx` (`Header` + `FeaturedGrid`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.onOpenMerchant, super.key});

  /// Called with a merchant id when its featured card is tapped.
  final ValueChanged<int> onOpenMerchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(merchantsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeader(),
              const SizedBox(height: 32),
              Text(
                'Bienvenido a Fudo',
                style: AppTheme.headline.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'Descubrí lugares y ganá descuentos por cada visita.',
                style: AppTheme.bodySecondary,
              ),
              const SizedBox(height: 28),
              Text(
                'Lugares destacados',
                style: AppTheme.title.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 12),
              merchantsAsync.when(
                data: (merchants) => FeaturedGrid(
                  merchants: merchants,
                  onOpenMerchant: onOpenMerchant,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                ),
                error: (error, stackTrace) => NetworkErrorView(
                  message: 'No pudimos cargar los lugares destacados.',
                  onRetry: () => ref.invalidate(merchantsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
