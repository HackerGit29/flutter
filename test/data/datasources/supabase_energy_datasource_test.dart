import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aricie/data/datasources/supabase_energy_datasource.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  group('SupabaseEnergyDataSource', () {
    test('getEnergyHistory scopes by user and default Jour timeframe', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'id': 'e-1', 'user_id': 'user-1', 'kwh': 1.5},
        ]);
      });
      final ds = SupabaseEnergyDataSource(client);

      final result = await ds.getEnergyHistory(userId: 'user-1');

      expect(result.single['id'], 'e-1');
      expect(captured.url.queryParameters['user_id'], 'eq.user-1');
      expect(captured.url.queryParameters['order'], 'date.desc.nullslast');
      expect(captured.url.queryParameters['limit'], '50');
    });

    test('getEnergyHistory scales limit for Semaine timeframe', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, []);
      });
      final ds = SupabaseEnergyDataSource(client);

      await ds.getEnergyHistory(userId: 'user-1', timeFrame: 'Semaine');

      expect(captured.url.queryParameters['limit'], '350');
    });

    test('getEnergyHistory scales limit for Mois and Année timeframes', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, []);
      });
      final ds = SupabaseEnergyDataSource(client);

      await ds.getEnergyHistory(userId: 'user-1', timeFrame: 'Mois');
      expect(captured.url.queryParameters['limit'], '1550');

      await ds.getEnergyHistory(userId: 'user-1', timeFrame: 'Année');
      expect(captured.url.queryParameters['limit'], '18300');
    });

    test('getEnergyByAppliance selects reduced columns', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return jsonOk(request, [
          {'appliance_id': 'app-1', 'kwh': 2.0},
        ]);
      });
      final ds = SupabaseEnergyDataSource(client);

      final result = await ds.getEnergyByAppliance(userId: 'user-1');

      expect(result.single['appliance_id'], 'app-1');
      expect(captured.url.queryParameters['select'], 'appliance_id,kwh');
    });
  });
}