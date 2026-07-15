import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage with an in-memory fallback.
///
/// On Flutter web, flutter_secure_storage uses the browser's Web Crypto API
/// and IndexedDB. Both can throw OperationError (corrupted key material from
/// a previous run) or fail silently. We always write to an in-memory map
/// first so the current session always has valid tokens even when persistence
/// fails. Persistence failure means tokens don't survive a page reload, but
/// the current session works correctly.
class TokenStorage {
  const TokenStorage();

  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'otuuse_transport',
      publicKey: 'otuuse_transport_key',
    ),
  );

  // In-memory fallback - static so it survives TokenStorage instances
  // being recreated by Riverpod between rebuilds.
  static final _cache = <String, String?>{};

  static const _accessKey  = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey  = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _userNameKey = 'user_name';

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessKey) ?? _cache[_accessKey];
    } catch (_) {
      return _cache[_accessKey];
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey) ?? _cache[_refreshKey];
    } catch (_) {
      return _cache[_refreshKey];
    }
  }

  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _userIdKey) ?? _cache[_userIdKey];
    } catch (_) {
      return _cache[_userIdKey];
    }
  }

  Future<String?> getRole() async {
    try {
      return await _storage.read(key: _userRoleKey) ?? _cache[_userRoleKey];
    } catch (_) {
      return _cache[_userRoleKey];
    }
  }

  Future<String?> getName() async {
    try {
      return await _storage.read(key: _userNameKey) ?? _cache[_userNameKey];
    } catch (_) {
      return _cache[_userNameKey];
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String role,
    String name = '',
  }) async {
    // Always write to memory first - this is what the Dio interceptor
    // reads on every request, so it must never be null after login.
    _cache[_accessKey]   = accessToken;
    _cache[_refreshKey]  = refreshToken;
    _cache[_userIdKey]   = userId;
    _cache[_userRoleKey] = role;
    _cache[_userNameKey] = name;

    // Then attempt to persist across page reloads. Failure is acceptable.
    try {
      await Future.wait([
        _storage.write(key: _accessKey,   value: accessToken),
        _storage.write(key: _refreshKey,  value: refreshToken),
        _storage.write(key: _userIdKey,   value: userId),
        _storage.write(key: _userRoleKey, value: role),
        _storage.write(key: _userNameKey, value: name),
      ]);
    } catch (_) {}
  }

  Future<void> clear() async {
    _cache.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
