import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/services/auth_service.dart';

import '../helpers/supabase_test_helper.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> store = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      store[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    store.clear();
  }
}

Map<String, dynamic> _authJson() => {
      'access_token': 'access-token-1',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh-token-1',
      'user': {
        'id': 'user-1',
        'aud': 'authenticated',
        'email': 'test@test.com',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    };

late Future<http.Response> Function(http.Request) _handler;
late _FakeSecureStoragePlatform _fakeStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _fakeStorage = _FakeSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = _fakeStorage;
    SharedPreferences.setMockInitialValues({});
    _handler = (request) async => emptyOk(request);
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) => _handler(request)),
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  });

  tearDown(() async {
    _handler = (request) async => emptyOk(request);
    _fakeStorage.store.clear();
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.signOut();
  });

  group('AuthService', () {
    test('isLoggedIn is false with no cached flag and no session', () async {
      final service = AuthService();

      expect(await service.isLoggedIn(), false);
    });

    test('isLoggedIn is false when flag set but no active Supabase session', () async {
      SharedPreferences.setMockInitialValues({'user_session': true});
      final service = AuthService();

      expect(await service.isLoggedIn(), false);
    });

    test('isLoggedIn is true once session flag and Supabase user both exist', () async {
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');
      final service = AuthService();
      await service.saveSession(Supabase.instance.client.auth.currentUser!);

      expect(await service.isLoggedIn(), true);
    });

    test('saveSession persists the session flag and secure user info', () async {
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');
      final user = Supabase.instance.client.auth.currentUser!;
      final service = AuthService();

      await service.saveSession(user);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_session'), true);
      expect(await service.getUserEmail(), 'test@test.com');
    });

    test('clearSession wipes the session flag and secure user info', () async {
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');
      final service = AuthService();
      await service.saveSession(Supabase.instance.client.auth.currentUser!);

      await service.clearSession();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_session'), false);
      expect(await service.getUserEmail(), isNull);
    });

    test('getUserEmail returns null before any session is saved', () async {
      final service = AuthService();

      expect(await service.getUserEmail(), isNull);
    });
  });
}
