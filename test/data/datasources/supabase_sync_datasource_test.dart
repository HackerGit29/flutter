import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_sync_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  group('SupabaseSyncDataSource', () {
    test('getBoxById returns null when missing', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, []),
      );
      final ds = SupabaseSyncDataSource(client);

      final result = await ds.getBoxById('box-1');

      expect(result, isNull);
    });

    test('getBoxById returns box when found', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'box-1', 'user_id': 'user-1'},
        ]),
      );
      final ds = SupabaseSyncDataSource(client);

      final result = await ds.getBoxById('box-1');

      expect(result?['id'], 'box-1');
    });

    test('verifyOwnership is false when box does not exist', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, []),
      );
      final ds = SupabaseSyncDataSource(client);

      final result = await ds.verifyOwnership('box-1', 'user-1');

      expect(result, false);
    });

    test('verifyOwnership is true when owner matches', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'box-1', 'user_id': 'user-1'},
        ]),
      );
      final ds = SupabaseSyncDataSource(client);

      final result = await ds.verifyOwnership('box-1', 'user-1');

      expect(result, true);
    });

    test('verifyOwnership is false when owner differs', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'box-1', 'user_id': 'other-user'},
        ]),
      );
      final ds = SupabaseSyncDataSource(client);

      final result = await ds.verifyOwnership('box-1', 'user-1');

      expect(result, false);
    });

    test('updateLastSync PATCHes last_sync timestamp', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOk(request);
      });
      final ds = SupabaseSyncDataSource(client);

      await ds.updateLastSync('box-1');

      expect(captured.method, 'PATCH');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('last_sync'), true);
    });

    test('createSyncLog inserts and returns log row', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {'id': 'log-1', 'status': 'success'}),
      );
      final ds = SupabaseSyncDataSource(client);

      final result = await ds.createSyncLog({'status': 'success'});

      expect(result['id'], 'log-1');
    });
  });
}