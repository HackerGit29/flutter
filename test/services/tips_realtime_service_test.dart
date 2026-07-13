import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/services/tips_realtime_service.dart';

import '../helpers/supabase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnergyTipEvent.fromJson', () {
    test('maps all fields from a realtime row', () {
      final event = EnergyTipEvent.fromJson({
        'id': 'tip-1',
        'title': 'Pic de consommation',
        'body': 'Le frigo consomme beaucoup',
        'icon': 'bolt',
        'severity': 'warning',
        'source': 'live_spike',
      });

      expect(event.id, 'tip-1');
      expect(event.title, 'Pic de consommation');
      expect(event.severity, 'warning');
      expect(event.source, 'live_spike');
    });
  });

  group('TipsRealtimeService', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        publishableKey: 'test-anon-key',
        httpClient: MockClient((request) async => emptyOk(request)),
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
    });

    test('start() is a no-op when nobody is logged in, and stays retryable', () {
      expect(Supabase.instance.client.auth.currentUser, isNull);

      TipsRealtimeService.instance.start();
      // Calling it again should not throw either, since _started was reset.
      TipsRealtimeService.instance.start();
    });

    test('dispose() is safe to call without ever starting', () async {
      await TipsRealtimeService.instance.dispose();
    });
  });
}