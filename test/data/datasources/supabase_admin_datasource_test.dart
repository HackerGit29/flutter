import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_admin_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  group('SupabaseAdminDataSource', () {
    test('getAllUsers orders by created_at desc', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'id': 'u-1'},
          {'id': 'u-2'},
        ]);
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.getAllUsers();

      expect(result.length, 2);
      expect(captured.url.queryParameters['order'], 'created_at.desc.nullslast');
    });

    test('getUserById returns the user', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {'id': 'u-1', 'role': 'user'}),
      );
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.getUserById('u-1');

      expect(result['role'], 'user');
    });

    test('updateUserStatus PATCHes status', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'suspended');
        return jsonOk(request, {'id': 'u-1', 'status': 'suspended'});
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.updateUserStatus('u-1', 'suspended');

      expect(result['status'], 'suspended');
    });

    test('updateUserRole PATCHes role', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['role'], 'admin');
        return jsonOk(request, {'id': 'u-1', 'role': 'admin'});
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.updateUserRole('u-1', 'admin');

      expect(result['role'], 'admin');
    });

    test('getAllBoxes orders by created_at desc', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'box-1'},
        ]),
      );
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.getAllBoxes();

      expect(result.single['id'], 'box-1');
    });

    test('getSyncLogs applies optional userId and boxId filters', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, []);
      });
      final ds = SupabaseAdminDataSource(client);

      await ds.getSyncLogs(userId: 'user-1', boxId: 'box-1');

      expect(captured.url.queryParameters['user_id'], 'eq.user-1');
      expect(captured.url.queryParameters['box_id'], 'eq.box-1');
    });

    test('getSyncLogs works without filters', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, []);
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.getSyncLogs();

      expect(result, isEmpty);
      expect(captured.url.queryParameters.containsKey('user_id'), false);
    });

    test('assignBoxToUser PATCHes user_id', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['user_id'], 'user-2');
        return jsonOk(request, {'id': 'box-1', 'user_id': 'user-2'});
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.assignBoxToUser('box-1', 'user-2');

      expect(result['user_id'], 'user-2');
    });

    test('overrideBoxOwnership updates box then cascades to appliances', () async {
      final requests = <http.Request>[];
      final client = buildTestSupabaseClient((request) async {
        requests.add(request);
        if (request.url.path.contains('appliances')) {
          return emptyOk(request);
        }
        return jsonOk(request, {'id': 'box-1', 'user_id': 'user-2'});
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.overrideBoxOwnership('box-1', 'user-2');

      expect(result['user_id'], 'user-2');
      expect(requests.length, 2);
      expect(requests[1].url.path, contains('appliances'));
    });

    test('resetBox clears uid_hardware, status and public_key', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['uid_hardware'], '');
        expect(body['status'], 'inactive');
        expect(body['public_key'], null);
        return jsonOk(request, {'id': 'box-1', 'status': 'inactive'});
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.resetBox('box-1');

      expect(result['status'], 'inactive');
    });

    test('forceSync fetches box, updates last_sync, and logs sync', () async {
      final requests = <http.Request>[];
      final client = buildTestSupabaseClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return jsonOk(request, {'id': 'box-1', 'user_id': 'user-1'});
        }
        if (request.url.path.contains('sync_logs')) {
          return jsonOk(request, {'id': 'log-1', 'box_id': 'box-1', 'status': 'success'});
        }
        return emptyOk(request);
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.forceSync('box-1');

      expect(result['id'], 'log-1');
      expect(requests.length, 3);
    });

    test('getAllSubscriptions orders by created_at desc', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'sub-1'},
        ]),
      );
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.getAllSubscriptions();

      expect(result.single['id'], 'sub-1');
    });

    test('updateSubscription PATCHes given data', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {'id': 'sub-1', 'is_active': false}),
      );
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.updateSubscription('sub-1', {'is_active': false});

      expect(result['is_active'], false);
    });

    test('logAdminAction inserts and returns action row', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {'id': 'action-1'}),
      );
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.logAdminAction({'action_type': 'suspend_user'});

      expect(result['id'], 'action-1');
    });

    test('getAvailableBoxes filters unassigned boxes', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'id': 'box-1', 'user_id': null},
        ]);
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.getAvailableBoxes();

      expect(result.single['id'], 'box-1');
      expect(captured.url.queryParameters['user_id'], 'is.null');
    });

    test('createBox includes optional location and userId when provided', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['uid_hardware'], 'hw-1');
        expect(body['location'], 'Paris');
        expect(body['user_id'], 'user-1');
        return jsonOk(request, {'id': 'box-1', 'uid_hardware': 'hw-1'});
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.createBox(
        uidHardware: 'hw-1',
        name: 'Salon',
        location: 'Paris',
        userId: 'user-1',
      );

      expect(result['id'], 'box-1');
    });

    test('createBox omits optional fields when not provided', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('location'), false);
        expect(body.containsKey('user_id'), false);
        return jsonOk(request, {'id': 'box-1'});
      });
      final ds = SupabaseAdminDataSource(client);

      await ds.createBox(uidHardware: 'hw-1', name: 'Salon');
    });

    test('createAppliancesForBox inserts three appliances', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as List;
        expect(body.length, 3);
        return jsonOk(request, [
          {'id': 'app-1', 'relay_index': 1},
          {'id': 'app-2', 'relay_index': 2},
          {'id': 'app-3', 'relay_index': 3},
        ]);
      });
      final ds = SupabaseAdminDataSource(client);

      final result = await ds.createAppliancesForBox('box-1', 'user-1');

      expect(result.length, 3);
    });

    test('getAdminActions limits and orders by timestamp desc', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, []);
      });
      final ds = SupabaseAdminDataSource(client);

      await ds.getAdminActions(limit: 10);

      expect(captured.url.queryParameters['limit'], '10');
      expect(captured.url.queryParameters['order'], 'timestamp.desc.nullslast');
    });

    test('getDeviceCommands limits and orders by created_at desc', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, []);
      });
      final ds = SupabaseAdminDataSource(client);

      await ds.getDeviceCommands();

      expect(captured.url.queryParameters['limit'], '50');
    });
  });
}