import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Login tokens live in the OS credential store (Windows Credential Manager / Keychain / Keystore), never in the
/// app database.
abstract class TokenStore {
  Future<String?> accessToken();
  Future<String?> refreshToken();
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _access = 'sa_access_token';
  static const _refresh = 'sa_refresh_token';

  @override
  Future<String?> accessToken() => _s.read(key: _access);

  @override
  Future<String?> refreshToken() => _s.read(key: _refresh);

  @override
  Future<void> save(String access, String refresh) async {
    await _s.write(key: _access, value: access);
    await _s.write(key: _refresh, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
  }
}

/// For tests.
class MemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<String?> accessToken() async => access;

  @override
  Future<String?> refreshToken() async => refresh;

  @override
  Future<void> save(String a, String r) async {
    access = a;
    refresh = r;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
