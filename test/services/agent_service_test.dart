import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/services/agent_service.dart';

import '../helpers/supabase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) async => emptyOk(request)),
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  });

  group('AgentService', () {
    test('getAccessToken returns empty string when nobody is logged in', () async {
      expect(await AgentService.instance.getAccessToken(), '');
    });

    test('streamMessage yields an auth error then done when logged out', () async {
      final events = await AgentService.instance
          .streamMessage(message: 'bonjour', sessionId: 'session-1')
          .toList();

      expect(events.length, 2);
      expect(events[0].event, 'error');
      expect(events[0].data['message'], contains('connecté'));
      expect(events[1].event, 'done');
    });
  });
}