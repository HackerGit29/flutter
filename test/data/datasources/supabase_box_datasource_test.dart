import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_box_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  group('SupabaseBoxDataSource', () {
    test('addBox POSTs to /boxes and returns inserted row', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, {
          'id': 'box-1',
          'name': 'Salon',
          'location': 'Paris',
          'user_id': 'user-1',
        });
      });
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.addBox('Salon', 'Paris', 'user-1');

      expect(result['id'], 'box-1');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/rest/v1/boxes');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['name'], 'Salon');
      expect(body['location'], 'Paris');
      expect(body['status'], 'inactive');
    });

    test('addBox omits location when null', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('location'), false);
        return jsonOk(request, {'id': 'box-1', 'name': 'Salon', 'user_id': 'user-1'});
      });
      final ds = SupabaseBoxDataSource(client);

      await ds.addBox('Salon', null, 'user-1');
    });

    test('removeBox DELETEs by id', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOk(request);
      });
      final ds = SupabaseBoxDataSource(client);

      await ds.removeBox('box-1');

      expect(captured.method, 'DELETE');
      expect(captured.url.queryParameters['id'], 'eq.box-1');
    });

    test('getUserBoxes returns list for user', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'id': 'box-1', 'user_id': 'user-1'},
          {'id': 'box-2', 'user_id': 'user-1'},
        ]);
      });
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.getUserBoxes('user-1');

      expect(result.length, 2);
      expect(captured.method, 'GET');
      expect(captured.url.queryParameters['user_id'], 'eq.user-1');
    });

    test('getUserBoxes returns empty list when none found', () async {
      final client = buildTestSupabaseClient((request) async => jsonOk(request, []));
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.getUserBoxes('user-1');

      expect(result, isEmpty);
    });

    test('updateBoxStatus PATCHes status', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOk(request);
      });
      final ds = SupabaseBoxDataSource(client);

      await ds.updateBoxStatus('box-1', 'active');

      expect(captured.method, 'PATCH');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['status'], 'active');
    });

    test('pairBox updates uid_hardware and status, scoped to user', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, {
          'id': 'box-1',
          'uid_hardware': 'hw-123',
          'status': 'active',
          'user_id': 'user-1',
        });
      });
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.pairBox('box-1', 'hw-123', 'user-1');

      expect(result['uid_hardware'], 'hw-123');
      expect(captured.url.queryParameters['user_id'], 'eq.user-1');
    });

    test('findBoxByUid returns null when not found', () async {
      final client = buildTestSupabaseClient((request) async => jsonOk(request, []));
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.findBoxByUid('hw-unknown');

      expect(result, isNull);
    });

    test('findBoxByUid returns matching box', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'box-1', 'uid_hardware': 'hw-123'},
        ]),
      );
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.findBoxByUid('hw-123');

      expect(result?['id'], 'box-1');
    });

    test('getBoxById returns box', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {'id': 'box-1', 'name': 'Salon'}),
      );
      final ds = SupabaseBoxDataSource(client);

      final result = await ds.getBoxById('box-1');

      expect(result['name'], 'Salon');
    });

    test('getBoxById throws when box does not exist', () async {
      final client = buildTestSupabaseClient(
        (request) async => errorResponse(request, 404, message: 'not found'),
      );
      final ds = SupabaseBoxDataSource(client);

      expect(() => ds.getBoxById('missing'), throwsA(isA<Object>()));
    });
  });
}