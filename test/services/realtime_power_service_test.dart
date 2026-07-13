import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/services/realtime_power_service.dart';

import '../helpers/supabase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimePowerReading.fromJson', () {
    test('maps a full row, including nested appliance name', () {
      final reading = RealtimePowerReading.fromJson({
        'appliance_id': 'app-1',
        'appliances': {'name': 'Frigo'},
        'power_kwh': 2,
        'instant_power_w': 150.5,
        'updated_at': '2026-01-01T12:00:00.000Z',
      });

      expect(reading.applianceId, 'app-1');
      expect(reading.applianceName, 'Frigo');
      expect(reading.powerKwh, 2.0);
      expect(reading.instantPowerW, 150.5);
    });

    test('defaults power to 0 and name/instant power when missing', () {
      final reading = RealtimePowerReading.fromJson({
        'appliance_id': 'app-1',
        'updated_at': '2026-01-01T12:00:00.000Z',
      });

      expect(reading.powerKwh, 0);
      expect(reading.applianceName, '');
      expect(reading.instantPowerW, isNull);
    });
  });

  group('RealtimePowerService', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        publishableKey: 'test-anon-key',
        httpClient: MockClient((request) async => emptyOk(request)),
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
    });

    test('dispose() is safe without ever starting', () async {
      await RealtimePowerService.instance.dispose();
    });
  });
}
