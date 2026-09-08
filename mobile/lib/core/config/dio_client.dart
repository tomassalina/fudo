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
/// ⚠️ As of this writing, nothing at this URL implements `/api/v1/*` yet —
/// only Rails' default `/up` health check responds; `GET /api/v1/merchants`
/// and `POST /api/v1/sessions` both 404. See the doc on `RemoteDataSource`
/// for the full caveat. This constant, and everything built from it, is
/// infrastructure written ahead of the API existing, not something that has
/// been exercised against a real server.
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
  static Dio create({TokenStorage? tokenStorage}) {
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
        onError: (error, handler) => _handleError(error, handler, storage),
      ),
    );

    return dio;
  }

  /// Reacts to a failed request.
  ///
  /// On a `401` (the token is missing/expired/invalid from the backend's
  /// point of view), we clear the locally stored token so the next
  /// [TokenStorage.readToken] call returns `null` instead of resending a
  /// token the backend has already rejected.
  ///
  /// **What this deliberately does NOT do**: implement a refresh-token flow.
  /// `PLAN.md` Fase 3 describes login as returning a single token ("un token
  /// (JWT vía gema `jwt`, o token de sesión simple)") with no mention of a
  /// refresh token or a token-expiry contract, so there's nothing defined to
  /// implement yet. It also does not trigger navigation back to a login
  /// screen — there is no login screen or router hook in this app yet (out
  /// of scope for this task). Once Fase 3 defines a refresh contract and a
  /// login screen exists, this is the place to wire both in.
  static Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
    TokenStorage storage,
  ) async {
    if (error.response?.statusCode == 401) {
      await storage.clearToken();
    }
    handler.next(error);
  }
}
