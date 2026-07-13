import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/services/profile_service.dart';

import '../helpers/supabase_test_helper.dart';

Map<String, dynamic> _authJson({Map<String, dynamic>? userMetadata}) => {
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
        'user_metadata': userMetadata ?? <String, dynamic>{},
      },
    };

// `Supabase.initialize` is a process-wide singleton that only runs once, so
// it is set up a single time for the file with a *swappable* handler — each
// test points [_handler] at its own fake-server logic before running.
late Future<http.Response> Function(http.Request) _handler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
    await Supabase.instance.client.auth.signOut();
  });

  group('ProfileService', () {
    test('getDisplayName returns null when no session', () async {
      final service = ProfileService();

      final result = await service.getDisplayName();

      expect(result, isNull);
    });

    test('getDisplayName returns null when metadata is blank', () async {
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson(userMetadata: {'display_name': '   '}));
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');
      final service = ProfileService();

      final result = await service.getDisplayName();

      expect(result, isNull);
    });

    test('getDisplayName returns trimmed name when set', () async {
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson(userMetadata: {'display_name': '  Tony  '}));
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');
      final service = ProfileService();

      final result = await service.getDisplayName();

      expect(result, 'Tony');
    });

    test('setDisplayName sends trimmed name to updateUser', () async {
      late http.Request captured;
      _handler = (request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        if (request.url.path == '/auth/v1/user') {
          captured = request;
          return jsonOk(request, {
            'id': 'user-1',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          });
        }
        return emptyOk(request);
      };
      await Supabase.instance.client.auth
          .signInWithPassword(email: 'test@test.com', password: 'pw123456');
      final service = ProfileService();

      await service.setDisplayName('  Tony Az  ');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['data']['display_name'], 'Tony Az');
    });
  });
}
