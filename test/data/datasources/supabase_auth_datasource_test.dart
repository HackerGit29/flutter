
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_auth_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

Map<String, dynamic> _authJson({
  String accessToken = 'access-token-1',
  String refreshToken = 'refresh-token-1',
  String userId = 'user-1',
  String email = 'test@test.com',
}) => {
      'access_token': accessToken,
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': refreshToken,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'email': email,
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    };

final _existingProfile = {
  'id': 'user-1',
  'email': 'test@test.com',
  'role': 'user',
  'status': 'active',
};

/// Handler used when a test only needs `signIn` to succeed (existing
/// profile found) so it can exercise a subsequent authenticated call.
Future<http.Response> Function(http.Request) _signedInHandler({
  Future<http.Response?> Function(http.Request)? extra,
}) {
  return (request) async {
    final override = extra == null ? null : await extra(request);
    if (override != null) return override;
    if (request.url.path == '/auth/v1/token') {
      return jsonOk(request, _authJson());
    }
    if (request.url.path == '/rest/v1/users' && request.method == 'GET') {
      return jsonOk(request, [_existingProfile]);
    }
    return emptyOk(request);
  };
}

void main() {
  group('SupabaseAuthDataSource', () {
    test('signIn returns existing profile when one is found', () async {
      final client = buildTestSupabaseClient(_signedInHandler());
      final ds = SupabaseAuthDataSource(client);

      final result = await ds.signIn('test@test.com', 'pw123456');

      expect(result['role'], 'user');
    });

    test('signIn creates a profile when none exists yet', () async {
      final requests = <http.Request>[];
      final client = buildTestSupabaseClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        if (request.url.path == '/rest/v1/users' && request.method == 'GET') {
          return jsonOk(request, []);
        }
        if (request.url.path == '/rest/v1/users' && request.method == 'POST') {
          return jsonOk(request, _existingProfile);
        }
        return emptyOk(request);
      });
      final ds = SupabaseAuthDataSource(client);

      final result = await ds.signIn('test@test.com', 'pw123456');

      expect(result['status'], 'active');
      expect(requests.any((r) => r.method == 'POST' && r.url.path == '/rest/v1/users'), true);
    });

    test('signIn throws when credentials are rejected', () async {
      final client = buildTestSupabaseClient(
        (request) async => errorResponse(request, 400, message: 'Invalid login credentials'),
      );
      final ds = SupabaseAuthDataSource(client);

      expect(() => ds.signIn('test@test.com', 'wrong'), throwsA(isA<Object>()));
    });

    test('signUp creates a new profile', () async {
      final client = buildTestSupabaseClient((request) async {
        if (request.url.path == '/auth/v1/signup') {
          return jsonOk(request, _authJson());
        }
        if (request.url.path == '/rest/v1/users') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['role'], 'user');
          return jsonOk(request, _existingProfile);
        }
        return emptyOk(request);
      });
      final ds = SupabaseAuthDataSource(client);

      final result = await ds.signUp('test@test.com', 'pw123456');

      expect(result['role'], 'user');
    });

    test('signUp falls back to existing profile on duplicate key error', () async {
      final client = buildTestSupabaseClient((request) async {
        if (request.url.path == '/auth/v1/signup') {
          return jsonOk(request, _authJson());
        }
        if (request.url.path == '/rest/v1/users' && request.method == 'POST') {
          return http.Response(
            jsonEncode({'message': 'duplicate key', 'code': '23505'}),
            409,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/rest/v1/users' && request.method == 'GET') {
          return jsonOk(request, [_existingProfile]);
        }
        return emptyOk(request);
      });
      final ds = SupabaseAuthDataSource(client);

      final result = await ds.signUp('test@test.com', 'pw123456');

      expect(result['id'], 'user-1');
    });

    test('signOut clears the session', () async {
      final client = buildTestSupabaseClient(_signedInHandler());
      final ds = SupabaseAuthDataSource(client);
      await ds.signIn('test@test.com', 'pw123456');

      await ds.signOut();

      expect(client.auth.currentSession, isNull);
    });

    test('resetPassword posts the recovery request', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOk(request);
      });
      final ds = SupabaseAuthDataSource(client);

      await ds.resetPassword('test@test.com');

      expect(captured.url.path, '/auth/v1/recover');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['email'], 'test@test.com');
    });

    test('verifyRecoveryOtp posts the recovery token', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, _authJson());
      });
      final ds = SupabaseAuthDataSource(client);

      await ds.verifyRecoveryOtp('test@test.com', '123456');

      expect(captured.url.path, '/auth/v1/verify');
    });

    test('updatePassword requires an active session', () async {
      final client = buildTestSupabaseClient((request) async => emptyOk(request));
      final ds = SupabaseAuthDataSource(client);

      expect(() => ds.updatePassword('newpassword123'), throwsA(isA<Object>()));
    });

    test('updatePassword succeeds when signed in', () async {
      final client = buildTestSupabaseClient(_signedInHandler(
        extra: (request) async {
          if (request.url.path == '/auth/v1/user') {
            return jsonOk(request, {
              'id': 'user-1',
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
            });
          }
          return null;
        },
      ));
      final ds = SupabaseAuthDataSource(client);
      await ds.signIn('test@test.com', 'pw123456');

      await ds.updatePassword('newpassword123');
    });

    test('verifyCurrentPassword throws when there is no active session', () async {
      final client = buildTestSupabaseClient((request) async => emptyOk(request));
      final ds = SupabaseAuthDataSource(client);

      expect(() => ds.verifyCurrentPassword('pw'), throwsA(isA<Object>()));
    });

    test('verifyCurrentPassword re-authenticates with the current email', () async {
      final client = buildTestSupabaseClient(_signedInHandler());
      final ds = SupabaseAuthDataSource(client);
      await ds.signIn('test@test.com', 'pw123456');

      await ds.verifyCurrentPassword('pw123456');
    });

    test('getCurrentUser returns null when not authenticated', () async {
      final client = buildTestSupabaseClient((request) async => emptyOk(request));
      final ds = SupabaseAuthDataSource(client);

      final result = await ds.getCurrentUser();

      expect(result, isNull);
    });

    test('getCurrentUser returns the profile row when authenticated', () async {
      final client = buildTestSupabaseClient(_signedInHandler());
      final ds = SupabaseAuthDataSource(client);
      await ds.signIn('test@test.com', 'pw123456');

      final result = await ds.getCurrentUser();

      expect(result?['role'], 'user');
    });

    test('getCurrentUser throws when profile row is missing', () async {
      var usersGetCalls = 0;
      final client = buildTestSupabaseClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, _authJson());
        }
        if (request.url.path == '/rest/v1/users' && request.method == 'GET') {
          usersGetCalls++;
          // First call is signIn's own profile lookup (found); the second
          // simulates the profile having disappeared by the time
          // getCurrentUser() is called.
          return jsonOk(request, usersGetCalls == 1 ? [_existingProfile] : []);
        }
        return emptyOk(request);
      });
      final ds = SupabaseAuthDataSource(client);
      await ds.signIn('test@test.com', 'pw123456');

      expect(() => ds.getCurrentUser(), throwsA(isA<Object>()));
    });

    test('refreshToken throws when there is no session', () async {
      final client = buildTestSupabaseClient((request) async => emptyOk(request));
      final ds = SupabaseAuthDataSource(client);

      expect(() => ds.refreshToken(), throwsA(isA<Object>()));
    });

    test('refreshToken returns the new access token', () async {
      var tokenCalls = 0;
      final client = buildTestSupabaseClient(_signedInHandler(
        extra: (request) async {
          if (request.url.path == '/auth/v1/token') {
            tokenCalls++;
            return jsonOk(
              request,
              _authJson(accessToken: tokenCalls == 1 ? 'access-token-1' : 'access-token-2'),
            );
          }
          return null;
        },
      ));
      final ds = SupabaseAuthDataSource(client);
      await ds.signIn('test@test.com', 'pw123456');

      final result = await ds.refreshToken();

      expect(result, 'access-token-2');
    });
  });
}