import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/security/token_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) _store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.unmodifiable(_store);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }
}

void main() {
  group('Security - OWASP Mobile', () {
    test('M1: JWT stored in Secure Storage', () async {
      final storage = FakeSecureStorage();
      final tokenManager = TokenManager(storage);

      await tokenManager.saveTokens('access-jwt', 'refresh-jwt');

      expect(await tokenManager.getAccessToken(), 'access-jwt');
      expect(await tokenManager.getRefreshToken(), 'refresh-jwt');
    });

    test('M1: clearTokens removes both tokens', () async {
      final storage = FakeSecureStorage();
      final tokenManager = TokenManager(storage);

      await tokenManager.saveTokens('access', 'refresh');
      await tokenManager.clearTokens();

      expect(await tokenManager.getAccessToken(), isNull);
      expect(await tokenManager.getRefreshToken(), isNull);
    });

    test('M7: needsRefresh returns true for expired token', () async {
      final storage = FakeSecureStorage();
      final tokenManager = TokenManager(storage);

      final payload = base64UrlEncode(utf8.encode('{"exp":1577836800}'));
      await storage.write(key: 'access_token', value: 'header.$payload.sig');

      expect(await tokenManager.needsRefresh(), isTrue);
    });
  });
}
