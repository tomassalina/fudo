/// Which [DataSource] implementation the app talks to — see
/// `data/providers.dart`'s `dataSourceProvider`.
enum ConnectionMode { local, remote }

/// Raw `CONNECTION_MODE` value resolved at compile time via
/// `--dart-define`/`--dart-define-from-file` — same pattern as
/// `core/config/dio_client.dart`'s `apiBaseUrl` and
/// `core/analytics/analytics_service.dart`'s PostHog vars.
const String _connectionModeEnvValue = String.fromEnvironment(
  'CONNECTION_MODE',
  defaultValue: 'local',
);

/// The resolved [ConnectionMode] for this build/run.
///
/// **Defaults to [ConnectionMode.local]**, and any value other than the
/// exact string `"remote"` also resolves to [ConnectionMode.local] — this is
/// a deliberate fail-safe, not just an unset-value default. Every
/// `flutter run`/`flutter test` invocation that doesn't pass
/// `--dart-define=CONNECTION_MODE=remote` keeps using `LocalDataSource`
/// (the bundled JSON fixtures), which matters today because nothing at
/// `/api/v1/*` exists on any reachable backend yet — see the doc on
/// `data/remote/remote_data_source.dart`. Only flip this once Fase 3 (the
/// real API) has shipped and this mobile-side infra has actually been
/// exercised against it.
const ConnectionMode connectionMode = _connectionModeEnvValue == 'remote'
    ? ConnectionMode.remote
    : ConnectionMode.local;
