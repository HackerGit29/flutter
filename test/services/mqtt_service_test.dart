import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/services/mqtt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MqttService', () {
    test('exposes broadcast streams right after construction', () {
      final service = MqttService();

      expect(service.connectionState, isNotNull);
      expect(service.connectionStateStream, isNotNull);
      expect(service.telemetryStream, isNotNull);
      expect(service.relayStatesStream, isNotNull);
      expect(service.latestTelemetry, isNull);
      expect(service.latestRelayStates, isNull);
    });

    test('initialize throws ArgumentError when no MQTT token is available', () async {
      final service = MqttService();

      expect(
        service.initialize(boxUid: 'box-1', mqttToken: ''),
        throwsArgumentError,
      );
    });
  });
}