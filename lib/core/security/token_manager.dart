import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aricie/core/constants.dart';
import 'dart:convert';

class TokenManager {
  final FlutterSecureStorage _storage;
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  TokenManager(this._storage);

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<bool> needsRefresh() async {
    final token = await getAccessToken();
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = _decodeBase64(parts[1]);
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry.subtract(AppConstants.tokenRefreshMargin));
    } catch (_) {
      return true;
    }
  }

  Map<String, dynamic> _decodeBase64(String str) {
    final normalized = str.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(normalized.length + (4 - normalized.length % 4) % 4, '=');
    final decoded = utf8.decode(base64.decode(padded));
    return json.decode(decoded) as Map<String, dynamic>;
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
