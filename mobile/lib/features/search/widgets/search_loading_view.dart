import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';

/// Loading view for the "Buscar" tab (design-brief §2.2): pulsing
/// `auto_awesome` icon, "Buscando los mejores lugares para vos…" copy with
/// the query quoted in italics, and a few shimmer skeleton placeholders.
class SearchLoadingView extends StatefulWidget {
  const SearchLoadingView({required this.query, super.key});

  final String query;

  @override
  State<SearchLoadingView> createState() => _SearchLoadingViewState();
}

class _SearchLoadingViewState extends State<SearchLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final t = _pulseController.value;
              return Opacity(
                opacity: 0.6 + (0.4 * t),
                child: Transform.scale(scale: 0.92 + (0.16 * t), child: child),
              );
            },
            child: const Icon(
              Symbols.auto_awesome,
              color: AppTheme.accent,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Buscando los mejores lugares para vos…',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '"${widget.query}"',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 40),
          const _ShimmerSkeleton(),
          const SizedBox(height: 16),
          const _ShimmerSkeleton(),
          const SizedBox(height: 16),
          const _ShimmerSkeleton(),
        ],
      ),
    );
  }
}

/// A single skeleton "card" placeholder that mirrors `_MerchantCard`
/// (`search_results_list.dart`) 1:1 — same `AspectRatio(16/9)` image box on
/// top of the same `Material` surface/radius, same `EdgeInsets.all(12)` text
/// area below — so results don't jump size once they arrive. The image box
/// and text bars share one shimmer sweep animation, same gradient-sweep
/// technique the previous placeholder used.
class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton();

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _shimmerBox(height: double.infinity, radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: _shimmerBox(height: 16, radius: 6),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _shimmerBox(
                      width: 46,
                      height: 20,
                      radius: AppTheme.radiusPill,
                    ),
                    const SizedBox(width: 8),
                    _shimmerBox(width: 60, height: 12, radius: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    required double height,
    required double radius,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(1 + 3 * t, 0),
              colors: const [
                AppTheme.surfaceSecondary,
                AppTheme.border,
                AppTheme.surfaceSecondary,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
