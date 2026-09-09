import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';

/// Reusable "this failed to load over the network" state: an icon, a
/// message, and a "Reintentar" button that re-runs [onRetry] — typically
/// `ref.invalidate(theProviderThatFailed)`.
///
/// Meant for content that blocks a screen/section when it fails to load (a
/// results list, a merchant's full detail, the consumer's profile) — not for
/// secondary/non-critical data (e.g. a dish's diet tags in the menu), which
/// should keep failing silently (`SizedBox.shrink()`) instead of nagging the
/// user with a retry button for something they don't need to see.
class NetworkErrorView extends StatelessWidget {
  const NetworkErrorView({
    required this.onRetry,
    this.message = 'No pudimos conectarnos. Revisá tu conexión.',
    super.key,
  });

  /// Called when the user taps "Reintentar".
  final VoidCallback onRetry;

  /// User-facing error message shown above the retry button.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.wifi_off,
              size: 40,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: AppTheme.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
