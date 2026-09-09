import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for the single auth token
/// issued by `POST /sessions` (see `PLAN.md` Fase 3/4 and
/// `data/auth/auth_repository.dart`).
///
/// This class holds no business logic — it only knows how to read/write/
/// clear one string value under a fixed key. Deciding *when* to save a token
/// (after a successful login) or clear one (on logout, or on a 401 response)
/// is the job of `AuthRepository` and `core/config/dio_client.dart`, not
/// this class.
class TokenStorage {
  const TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// The key the token is stored under. Not exposed — callers only ever
  /// interact with the token as a whole via the methods below.
  static const _tokenKey = 'auth_token';

  /// The currently stored token, or `null` if none was ever saved (or it was
  /// cleared via [clearToken]).
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Persists [token], overwriting whatever was stored before.
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Removes the stored token, if any. Safe to call even when nothing was
  /// ever saved.
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
