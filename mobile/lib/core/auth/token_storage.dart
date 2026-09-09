import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for the durable auth session:
/// the JWT issued by `POST /sessions` and a JSON snapshot of the logged-in
/// consumer (`data/models/consumer.dart`'s `Consumer`, see `PLAN.md` Fase
/// 3/4 and `data/auth/auth_repository.dart`).
///
/// The consumer snapshot is stored alongside the token — not just the
/// token — because the real backend has **no endpoint to fetch "my own
/// profile"** (see `data/auth/current_consumer_session.dart`'s doc): the
/// only source of a full `Consumer` object is the response body of
/// `POST /sessions`/`POST /registrations`. Without persisting that response
/// too, a cold-start session restore (`AuthRepository.restoreSession()`)
/// would have a valid token but no profile to show for it.
///
/// This class holds no business logic — it only knows how to read/write/
/// clear these values under fixed keys, as plain strings (the consumer
/// snapshot is the caller's responsibility to encode/decode — see
/// [AuthRepository]'s use of `jsonEncode`/`Consumer.fromJson`, kept out of
/// this class so it doesn't need to depend on the domain model). Deciding
/// *when* to save these (after a successful login), restore them (on cold
/// start), or clear them (on logout, or on a 401 response) is the job of
/// `AuthRepository` and `core/config/dio_client.dart`, not this class.
class TokenStorage {
  const TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// The key the token is stored under. Not exposed — callers only ever
  /// interact with the token as a whole via the methods below.
  static const _tokenKey = 'auth_token';

  /// The key the JSON-encoded consumer snapshot is stored under.
  static const _consumerKey = 'auth_consumer';

  /// The currently stored token, or `null` if none was ever saved (or it was
  /// cleared via [clearToken]/[clearSession]).
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Persists [token], overwriting whatever was stored before.
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Removes the stored token, if any. Safe to call even when nothing was
  /// ever saved.
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// The currently stored consumer snapshot as a raw JSON string (decode via
  /// `Consumer.fromJson(jsonDecode(...))`), or `null` if none was ever
  /// saved (or it was cleared via [clearConsumerJson]/[clearSession]).
  Future<String?> readConsumerJson() => _storage.read(key: _consumerKey);

  /// Persists [json] (the result of `jsonEncode(consumer.toJson())`),
  /// overwriting whatever was stored before.
  Future<void> saveConsumerJson(String json) =>
      _storage.write(key: _consumerKey, value: json);

  /// Removes the stored consumer snapshot, if any. Safe to call even when
  /// nothing was ever saved.
  Future<void> clearConsumerJson() => _storage.delete(key: _consumerKey);

  /// Clears the whole durable session — both [clearToken] and
  /// [clearConsumerJson] — so a stale token is never left paired with a
  /// stale (or now-orphaned) consumer snapshot, or vice versa.
  Future<void> clearSession() async {
    await clearToken();
    await clearConsumerJson();
  }
}
