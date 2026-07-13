import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_appliance_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  group('SupabaseApplianceDataSource', () {
    test('getUserAppliances flattens nested box_uid and drops boxes', () async {
      final client = buildTestSupabaseClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['user_id'], 'eq.user-1');
        return jsonOk(request, [
          {
            'id': 'app-1',
            'user_id': 'user-1',
            'boxes': {'uid_hardware': 'hw-1'},
          },
        ]);
      });
      final ds = SupabaseApplianceDataSource(client);

      final result = await ds.getUserAppliances('user-1');

      expect(result.single['box_uid'], 'hw-1');
      expect(result.single.containsKey('boxes'), false);
    });

    test('getUserAppliances handles appliance with no box', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'app-1', 'user_id': 'user-1', 'boxes': null},
        ]),
      );
      final ds = SupabaseApplianceDataSource(client);

      final result = await ds.getUserAppliances('user-1');

      expect(result.single.containsKey('box_uid'), false);
    });

    test('getBoxAppliances orders by relay_index ascending', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'id': 'app-1', 'relay_index': 1},
          {'id': 'app-2', 'relay_index': 2},
        ]);
      });
      final ds = SupabaseApplianceDataSource(client);

      final result = await ds.getBoxAppliances('box-1');

      expect(result.length, 2);
      expect(captured.url.queryParameters['order'], 'relay_index.asc.nullslast');
    });

    test('updateApplianceName PATCHes name and returns updated row', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Frigo');
        return jsonOk(request, {'id': 'app-1', 'name': 'Frigo'});
      });
      final ds = SupabaseApplianceDataSource(client);

      final result = await ds.updateApplianceName('app-1', 'Frigo');

      expect(result['name'], 'Frigo');
    });

    test('toggleAppliance throws when not authenticated', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {}),
      );
      final ds = SupabaseApplianceDataSource(client);

      expect(() => ds.toggleAppliance('app-1', true), throwsA(isA<Exception>()));
    });

    test('toggleAppliance inserts a device command when authenticated', () async {
      final requests = <http.Request>[];
      final client = buildTestSupabaseClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/v1/token') {
          return jsonOk(request, {
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
          });
        }
        if (request.url.path == '/rest/v1/appliances' && request.method == 'GET') {
          return jsonOk(request, {
            'id': 'app-1',
            'box_id': 'box-1',
            'relay_index': 1,
            'name': 'Frigo',
            'boxes': {'uid_hardware': 'hw-1'},
          });
        }
        if (request.url.path == '/rest/v1/device_commands') {
          return emptyOk(request);
        }
        return emptyOk(request);
      });
      final ds = SupabaseApplianceDataSource(client);
      await client.auth.signInWithPassword(email: 'test@test.com', password: 'pw123456');

      final result = await ds.toggleAppliance('app-1', true);

      expect(result['box_uid'], 'hw-1');
      expect(result.containsKey('boxes'), false);
      final commandRequest = requests.firstWhere((r) => r.url.path == '/rest/v1/device_commands');
      final body = jsonDecode(commandRequest.body) as Map<String, dynamic>;
      expect(body['action'], 'on');
      expect(body['user_id'], 'user-1');
    });
  });
}