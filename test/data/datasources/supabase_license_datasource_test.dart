import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_license_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  group('SupabaseLicenseDataSource', () {
    test('getUserSubscription returns null when none exists', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, []),
      );
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.getUserSubscription('user-1');

      expect(result, isNull);
    });

    test('getUserSubscription returns subscription when found', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'sub-1', 'user_id': 'user-1', 'type': 'free'},
        ]),
      );
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.getUserSubscription('user-1');

      expect(result?['id'], 'sub-1');
    });

    test('createSubscription posts type and active flag', () async {
      final client = buildTestSupabaseClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'vip');
        expect(body['is_active'], true);
        return jsonOk(request, {'id': 'sub-1', 'type': 'vip', 'is_active': true});
      });
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.createSubscription('user-1', 'vip');

      expect(result['type'], 'vip');
    });

    test('updateSubscription PATCHes given data', () async {
      final client = buildTestSupabaseClient((request) async {
        expect(request.method, 'PATCH');
        return jsonOk(request, {'id': 'sub-1', 'is_active': false});
      });
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.updateSubscription('sub-1', {'is_active': false});

      expect(result['is_active'], false);
    });

    test('getLicenseByKey returns null when not found', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, []),
      );
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.getLicenseByKey('KEY-404');

      expect(result, isNull);
    });

    test('createLicense inserts given data', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, {'id': 'lic-1'}),
      );
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.createLicense({'license_key': 'KEY-1'});

      expect(result['id'], 'lic-1');
    });

    test('getLicenseBySubscription returns matching license', () async {
      final client = buildTestSupabaseClient(
        (request) async => jsonOk(request, [
          {'id': 'lic-1', 'subscription_id': 'sub-1'},
        ]),
      );
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.getLicenseBySubscription('sub-1');

      expect(result?['id'], 'lic-1');
    });

    test('findProductKey selects reduced columns', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'id': 'pk-1', 'is_used': false, 'expires_at': null},
        ]);
      });
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.findProductKey('ABC-123');

      expect(result?['id'], 'pk-1');
      expect(captured.url.queryParameters['key'], 'eq.ABC-123');
    });

    test('claimProductKey returns null when key already used', () async {
      final client = buildTestSupabaseClient(
        (request) async => emptyOk(request),
      );
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.claimProductKey('pk-1', 'user-1');

      expect(result, isNull);
    });

    test('claimProductKey marks key as used for the claiming user', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['used_by'], 'user-1');
        expect(body['is_used'], true);
        return jsonOk(request, {'id': 'pk-1'});
      });
      final ds = SupabaseLicenseDataSource(client);

      final result = await ds.claimProductKey('pk-1', 'user-1');

      expect(result?['id'], 'pk-1');
      expect(captured.url.queryParameters['is_used'], 'eq.false');
    });
  });
}