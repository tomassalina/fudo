import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/auth/token_storage.dart';
import '../models/consumer.dart';
import 'current_consumer_session.dart';

/// Login/registration for the demo consumer, backed by the real backend at
/// `http://localhost:3000/api/v1` (verified live — see the class-level
/// caveats below for what's confirmed vs. inferred).
///
/// Kept separate from [DataSource] on purpose: authentication isn't part of
/// the merchants/menu_items/visits/etc data model — every [DataSource]
/// method just *relies* on a token already being present (attached via the
/// `Authorization` header by `core/config/dio_client.dart`), it doesn't
/// manage that token's lifecycle.
///
/// **Confirmed contract** (verified live against the running backend and its
/// generated OpenAPI doc at `GET /api-docs/v1/swagger.yaml`):
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
///
/// POST /api/v1/registrations
/// request:  { "registration": { "email", "password",
///                                "password_confirmation", "first_name",
///                                "last_name", "dni"?, "phone"? } }
/// 201:      same shape as POST /sessions's 200
/// 422:      { "errors": {...} }  // duplicate email/dni, password mismatch,
///                                // missing fields
/// ```
/// `dni` is now **optional** (backend commit `1cdb20e`, per
/// `openspec/changes/fudo-consumers-mvp/design.md` Decisión 1: the DNI is
/// loaded by the waiter at checkout in the physical restaurant, not
/// self-reported by the consumer at registration). The key must be **absent**
/// from the request body to register without one — the backend's
/// `allow_nil: true` uniqueness check only treats a `nil` `dni` as "no dni";
/// sending `dni: ""` would set a real (non-nil) empty-string value, which
/// stays unique-constrained and would 422 on a second such registration.
/// [register] mirrors [phone]'s existing null-aware map-entry pattern for
/// this reason — never pass an empty string, pass `null`/omit the argument.
/// `hasDniOnFile: true` in [_storeConsumerSnapshot] is therefore only a
/// guaranteed fact for consumers who *did* supply a [dni] here — see
/// [CurrentConsumerSession]'s doc for where that's used.
///
/// Neither response includes `has_dni_on_file` (a required, non-nullable
/// field on [Consumer]), so the raw `consumer` object here is never parsed
/// through [Consumer.fromJson] directly — [_storeConsumerSnapshot] builds the
/// [Consumer] by hand, filling in `hasDniOnFile` per the inference above.
///
/// Callers should catch [DioException] and, on a 401/422, read
/// `e.response?.data['error']`/`['errors']` for the user-facing message —
/// this class doesn't wrap/translate that error itself, it's still pure
/// plumbing with no UI wired to it yet.
class AuthRepository {
  AuthRepository(
    this._dio, {
    TokenStorage? tokenStorage,
    this._consumerSession,
  }) : _tokenStorage = tokenStorage ?? const TokenStorage();

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Shared with `RemoteDataSource.getCurrentConsumer()` (see
  /// `data/providers.dart`, where both are built from the same
  /// `currentConsumerSessionProvider` instance) so a successful login here
  /// makes the profile available there. `null` when this repository is used
  /// without that wiring (e.g. in isolation in a unit test) — snapshotting
  /// is then simply skipped.
  final CurrentConsumerSession? _consumerSession;

  /// Logs in with [email]/[password], persists the returned token via
  /// [TokenStorage.saveToken], and snapshots the returned `consumer` object
  /// into [CurrentConsumerSession] (if one was provided). Throws
  /// [DioException] on a network/HTTP failure (401 included — see this
  /// class's doc comment for the error body shape), or [StateError] if a 2xx
  /// response is missing the confirmed top-level `token` field.
  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/sessions',
      data: {'email': email, 'password': password},
    );
    await _persistSession(response.data, endpoint: '/sessions');
  }

  /// Registers a new consumer and, on success, logs them in immediately —
  /// same response shape and token/session handling as [login]. `dni` and
  /// `phone` follow the confirmed `POST /registrations` contract above.
  ///
  /// `dni` is optional (see this class's doc comment) — pass `null` (the
  /// default) or omit it entirely to register without one; the key is then
  /// left out of the request body rather than sent as an empty string, which
  /// matters for how the backend's uniqueness check treats it.
  ///
  /// Throws [DioException] on a network/HTTP failure (422 validation
  /// failures included), or [StateError] if a 2xx response is missing the
  /// confirmed top-level `token` field.
  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    required String lastName,
    String? dni,
    String? phone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/registrations',
      data: {
        'registration': {
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'first_name': firstName,
          'last_name': lastName,
          'dni': ?dni,
          'phone': ?phone,
        },
      },
    );
    await _persistSession(
      response.data,
      endpoint: '/registrations',
      // Unlike before `dni` became optional, this is no longer a guaranteed
      // `true` for every registration — see [_storeConsumerSnapshot].
      hasDniOnFile: dni != null && dni.isNotEmpty,
    );
  }

  Future<void> _persistSession(
    Map<String, dynamic>? data, {
    required String endpoint,
    bool hasDniOnFile = true,
  }) async {
    final token = data?['token'] as String?;
    if (token == null) {
      throw StateError(
        'POST $endpoint succeeded but the response had no "token" field. '
        'This contradicts the confirmed contract documented on this class '
        '— either the backend changed, or something else is wrong.',
      );
    }
    await _tokenStorage.saveToken(token);
    await _storeConsumerSnapshot(
      data?['consumer'] as Map<String, dynamic>?,
      hasDniOnFile: hasDniOnFile,
    );
  }

  /// Builds a [Consumer] from the partial `consumer` object embedded in a
  /// login/register response (missing `has_dni_on_file`, see class doc),
  /// stores it on [_consumerSession] (in-memory, for [RemoteDataSource]'s
  /// `getCurrentConsumer()` this session), and persists it to
  /// [_tokenStorage] alongside the token (for [restoreSession] on a future
  /// cold start). The disk write happens regardless of whether
  /// [_consumerSession] was provided — the two are independent concerns,
  /// unlike before this method also persisted to disk. A no-op if
  /// [consumerJson] is somehow missing despite a 2xx response (defensive —
  /// not expected per the confirmed contract).
  Future<void> _storeConsumerSnapshot(
    Map<String, dynamic>? consumerJson, {
    required bool hasDniOnFile,
  }) async {
    if (consumerJson == null) return;
    final consumer = Consumer(
      id: consumerJson['id'] as String,
      firstName: consumerJson['first_name'] as String,
      lastName: consumerJson['last_name'] as String,
      email: consumerJson['email'] as String,
      phone: consumerJson['phone'] as String?,
      // [login]'s call site leaves this at its `true` default — the
      // session endpoint doesn't return `has_dni_on_file` either, so a
      // logged-in-via-[login] consumer is still assumed to have one on
      // file (pre-existing assumption, unchanged by this fix). [register]
      // passes the real answer instead, since `dni` becoming optional
      // (backend `1cdb20e`) means that assumption no longer holds there.
      hasDniOnFile: hasDniOnFile,
    );
    _consumerSession?.consumer = consumer;
    await _tokenStorage.saveConsumerJson(jsonEncode(consumer.toJson()));
  }

  /// Attempts to restore a session persisted by a previous
  /// [login]/[register] call — used on cold start so a durable login
  /// survives an app relaunch instead of forcing the user to log in again
  /// every time (see `data/providers.dart`'s `sessionRestoreProvider`,
  /// the only real caller).
  ///
  /// This is a purely **local** operation: it loads whatever
  /// [TokenStorage] has on disk into [_consumerSession] and returns
  /// whether there was a complete session to restore. It does NOT validate
  /// the token against the backend — the real API has no dedicated
  /// "who am I"/token-validation endpoint (see
  /// `RemoteDataSource.getCurrentConsumer()`'s doc), so callers that need
  /// that confirmation make a real authenticated request of their own and
  /// call [logout] if it comes back `401` (`sessionRestoreProvider` does
  /// exactly this).
  ///
  /// Returns `false` (and leaves nothing behind, clearing via
  /// [TokenStorage.clearSession] if a half-session was found) when:
  /// - there is no persisted token at all, or
  /// - a token exists but its consumer snapshot is missing or fails to
  ///   parse — shouldn't happen, since [_storeConsumerSnapshot] always
  ///   writes both together, but local storage can end up partially
  ///   cleared/corrupted, and restoring a token with no profile behind it
  ///   would crash the first screen that reads `currentConsumerProvider`
  ///   (see `RemoteDataSource.getCurrentConsumer()`'s `StateError`).
  Future<bool> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null) return false;

    final consumerJson = await _tokenStorage.readConsumerJson();
    if (consumerJson == null) {
      await _tokenStorage.clearSession();
      return false;
    }

    try {
      final consumer = Consumer.fromJson(
        jsonDecode(consumerJson) as Map<String, dynamic>,
      );
      _consumerSession?.consumer = consumer;
      return true;
    } catch (_) {
      // Corrupted/unexpected local data — fail closed (logged out) rather
      // than crash on a malformed cached snapshot.
      await _tokenStorage.clearSession();
      return false;
    }
  }

  /// Clears the locally stored token+consumer snapshot
  /// ([TokenStorage.clearSession]) and the in-memory consumer snapshot.
  /// Does not call any backend endpoint — there is no server-side
  /// session-invalidation endpoint (e.g. `DELETE /sessions`) in the
  /// confirmed API, so this is local-only for now.
  Future<void> logout() async {
    await _tokenStorage.clearSession();
    _consumerSession?.consumer = null;
  }
}
