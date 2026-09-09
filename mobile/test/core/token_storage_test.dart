// Tests for `TokenStorage` (core/auth/token_storage.dart).
//
// `flutter_secure_storage` talks to native platform code over a
// `MethodChannel`, which doesn't exist under `flutter test`'s Dart-only VM.
// The package ships no official in-memory test double (unlike e.g.
// `shared_preferences`'s `setMockInitialValues`), but its plugin-platform-
// interface design makes one easy to write: `FlutterSecureStorage` itself
// only ever talks to `FlutterSecureStoragePlatform.instance`, so swapping
// that static instance for a plain in-memory `Map`-backed fake exercises
// `TokenStorage`'s real read/write/delete logic without touching a
// platform channel at all.
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/token_storage.dart';

/// In-memory stand-in for the native secure storage platform channel.
class _FakeFlutterSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map.of(_values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

void main() {
  late _FakeFlutterSecureStoragePlatform fakePlatform;
  late TokenStorage tokenStorage;

  setUp(() {
    fakePlatform = _FakeFlutterSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = fakePlatform;
    tokenStorage = const TokenStorage();
  });

  test('readToken returns null when nothing was ever saved', () async {
    expect(await tokenStorage.readToken(), isNull);
  });

  test('saveToken then readToken round-trips the value', () async {
    await tokenStorage.saveToken('abc123');

    expect(await tokenStorage.readToken(), 'abc123');
  });

  test('saveToken overwrites a previously saved token', () async {
    await tokenStorage.saveToken('first');
    await tokenStorage.saveToken('second');

    expect(await tokenStorage.readToken(), 'second');
  });

  test('clearToken removes a saved token', () async {
    await tokenStorage.saveToken('abc123');

    await tokenStorage.clearToken();

    expect(await tokenStorage.readToken(), isNull);
  });

  test('clearToken is a no-op when nothing was ever saved', () async {
    await tokenStorage.clearToken();

    expect(await tokenStorage.readToken(), isNull);
  });
}
