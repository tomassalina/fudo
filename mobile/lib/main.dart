import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'core/analytics/analytics_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setupAnalytics();
  runApp(const ProviderScope(child: FudoConsumersApp()));
}

/// Initializes PostHog Cloud analytics/feature flags (PRD.md: "Feature
/// flags, A/B testing y analytics de producto: todo con PostHog Cloud,
/// nunca self-hosteado").
///
/// SAFE NO-OP TODAY: [posthogApiKey] resolves to [posthogApiKeyPlaceholder]
/// until a real PostHog Cloud project key is supplied via
/// `--dart-define=POSTHOG_API_KEY=...` (or
/// `--dart-define-from-file=mobile/.env`, see `mobile/.env.example` /
/// `ENV_SETUP.md` §4). **Never replace the placeholder with a real key
/// here** — that would commit a secret to git. While the placeholder is in
/// place, `Posthog().setup` is never called below, so there are no PostHog
/// network requests in local development or under `flutter test`.
Future<void> _setupAnalytics() async {
  if (!isPosthogConfigured) return;
  final config = PostHogConfig(posthogApiKey)..host = posthogHost;
  await Posthog().setup(config);
}

class FudoConsumersApp extends StatelessWidget {
  const FudoConsumersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fudo Consumers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
