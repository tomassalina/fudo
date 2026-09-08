import 'package:dio/dio.dart';

import '../../core/auth/token_storage.dart';

/// Login/logout for the demo consumer.
///
/// Kept separate from [DataSource] on purpose: authentication isn't part of
/// the merchants/menu_items/visits/etc data model — every [DataSource]
/// method just *relies* on a token already being present (attached via the
/// `Authorization` header by `core/config/dio_client.dart`), it doesn't
/// manage that token's lifecycle.
///
/// ⚠️ Same caveat as `data/remote/remote_data_source.dart`: `POST /sessions`
/// does not exist on any backend reachable today
/// (`http://localhost:3000/api/v1/sessions` 404s — that's an old container
/// built from `main`, which doesn't have Fase 3 merged yet). Fase 3 itself
/// IS done and committed on the `backend-rails` branch, just not merged or
/// reachable from here yet.
///
/// **Confirmed contract** (from backend-rails-37, sourced from their
/// generated OpenAPI doc — not a guess):
/// ```
/// POST /api/v1/sessions
/// request:  { "email": "string", "password": "string" }
/// 200:      { "consumer": { "id": "uuid", "email": "string",
///                            "first_name": "string", "last_name": "string",
///                            "phone": "string|null" },
///              "token": "string (JWT)" }
/// 401:      { "error": "Invalid email or password" }  // deliberately
///                                                      // generic, doesn't
///                                                      // leak whether the
///                                                      // email exists
/// ```
/// `token` is read directly (still top-level, as this code already assumed
/// before the contract was confirmed). The `consumer` object in the
/// response is deliberately NOT parsed into a [Consumer] here — it's
/// missing `has_dni_on_file` (a required, non-nullable field on that
/// model), so forcing it through `Consumer.fromJson` would throw. Once
/// logged in, callers should re-fetch the authoritative profile via
/// `currentConsumerProvider` (`GET /me`) instead of trusting this partial
/// snapshot.
///
/// Callers should catch [DioException] and, on a 401, read
/// `e.response?.data['error']` for the user-facing message above — this
/// method doesn't wrap/translate that error itself, it's still pure
/// plumbing with no UI wired to it yet.
class AuthRepository {
  AuthRepository(this._dio, {TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Logs in with [email]/[password] and persists the returned token via
  /// [TokenStorage.saveToken] on success. Throws [DioException] on a
  /// network/HTTP failure (401 included — see this class's doc comment for
  /// the error body shape), or [StateError] if a 2xx response is missing
  /// the confirmed top-level `token` field.
  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/sessions',
      data: {'email': email, 'password': password},
    );
    final token = response.data?['token'] as String?;
    if (token == null) {
      throw StateError(
        'POST /sessions succeeded but the response had no "token" field. '
        'This contradicts the confirmed contract documented on this class '
        '— either the backend changed, or something else is wrong.',
      );
    }
    await _tokenStorage.saveToken(token);
  }

  /// Clears the locally stored token. Does not call any backend endpoint —
  /// `PLAN.md` doesn't define a server-side session-invalidation endpoint
  /// (e.g. `DELETE /sessions`), so this is local-only for now.
  Future<void> logout() => _tokenStorage.clearToken();
}
