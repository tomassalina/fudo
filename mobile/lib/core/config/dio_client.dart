import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// The backend API's base URL, resolved at compile time via
/// `--dart-define`/`--dart-define-from-file` (`API_BASE_URL`) — same
/// pattern `core/analytics/analytics_service.dart` uses for PostHog's env
/// vars. See `mobile/.env.example` and `ENV_SETUP.md` §5.
///
/// Defaults to the local Rails dev server URL documented in `PLAN.md` Fase 3
/// / `mobile/.env.example`.
///
/// This URL is live and confirmed working end-to-end against a real Rails
/// backend (30 seeded merchants) — see `RemoteDataSource`'s doc comment and
/// `test/integration/remote_data_source_live_test.dart` for the verified
/// contract and a real end-to-end test run against it.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);

/// Builds the [Dio] HTTP client used by `RemoteDataSource` and
/// `AuthRepository` once `CONNECTION_MODE=remote` is set (see
/// `data/connection_mode.dart`). Not used at all while the app runs in the
/// default `local` connection mode.
class DioClient {
  DioClient._();

  /// Creates a fresh, fully-configured [Dio] instance.
  ///
  /// - `baseUrl` is [apiBaseUrl].
  /// - `connectTimeout`/`receiveTimeout` are capped at 10s so a backend that
  ///   isn't responding — true today, see [apiBaseUrl]'s doc — fails fast
  ///   instead of hanging the UI indefinitely.
  /// - An [InterceptorsWrapper] attaches `Authorization: Bearer <token>` to
  ///   every outgoing request when [tokenStorage] has a saved token, and
  ///   reacts to `401` responses (see [_handleError]).
  /// - [onUnauthorized], if given, is invoked synchronously (fire-and-forget
  ///   — not awaited) whenever a `401` comes back, in addition to clearing
  ///   the stored token. This is how `data/providers.dart`'s `dioProvider`
  ///   plugs in the Riverpod-level reaction (flipping `isLoggedInProvider`
  ///   and clearing the in-memory `CurrentConsumerSession`) without this
  ///   file itself needing to depend on Riverpod — this class stays a plain
  ///   Dio/HTTP concern, the app-state reaction is the caller's job.
  static Dio create({
    TokenStorage? tokenStorage,
    void Function()? onUnauthorized,
  }) {
    final storage = tokenStorage ?? const TokenStorage();
    final dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) =>
            _handleError(error, handler, storage, onUnauthorized),
      ),
    );

    return dio;
  }

  /// Reacts to a failed request.
  ///
  /// On a `401` (the token is missing/expired/invalid from the backend's
  /// point of view), we clear the whole locally stored session — token AND
  /// the cached consumer snapshot ([TokenStorage.clearSession], not just
  /// [TokenStorage.clearToken]: a token the backend just rejected means the
  /// cached profile behind it is stale too) — so the next
  /// [TokenStorage.readToken] call returns `null` instead of resending a
  /// token the backend has already rejected, and invoke [onUnauthorized]
  /// (see [create]'s doc) so the app can react — flipping the login screen
  /// on, which was previously a documented gap here (there was no login
  /// screen yet when this comment was first written; there is one now,
  /// `features/my_places/my_places_screen.dart`'s `_LoggedOutView`, reached
  /// via the `ShellRoute`-level auth gate in `core/router/app_router.dart`
  /// once `isLoggedInProvider` reflects the logout).
  ///
  /// **What this deliberately still does NOT do**: implement a
  /// refresh-token flow. `PLAN.md` Fase 3 describes login as returning a
  /// single token ("un token (JWT vía gema `jwt`, o token de sesión
  /// simple)") with no mention of a refresh token or a token-expiry
  /// contract, so there's nothing defined to implement yet.
  static Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
    TokenStorage storage,
    void Function()? onUnauthorized,
  ) async {
    if (error.response?.statusCode == 401) {
      await storage.clearSession();
      onUnauthorized?.call();
    }
    handler.next(error);
  }
}
