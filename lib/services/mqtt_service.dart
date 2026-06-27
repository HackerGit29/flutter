import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:aricie/models/box_telemetry.dart';
import 'package:flutter/foundation.dart';
import 'package:aricie/core/constants.dart';
import 'package:mqtt5_client/mqtt5_client.dart';

import 'mqtt/mqtt5_client_interface.dart';
import 'mqtt/mqtt_client_factory.dart'
    if (dart.library.js_interop) 'mqtt/mqtt_client_factory_web.dart';

class MqttService {
  static const int _tcpTlsPort = 8883;
  static const int _wssPort = 443;
  late Mqtt5ClientInterface _client;

  late StreamController<MqttConnectionState> _connectionStateController;
  late StreamController<BoxTelemetry> _telemetryController;

  StreamSubscription? _updatesSubscription;

  BoxTelemetry? _latestTelemetry;

  bool _isInitializing = false;
  bool _initialized = false;

  String? _boxUid;
  String? _mqttToken;

  Stream<MqttConnectionState> get connectionState =>
      _connectionStateController.stream;

  Stream<BoxTelemetry> get telemetryStream => _telemetryController.stream;

  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  BoxTelemetry? get latestTelemetry => _latestTelemetry;

  /// Crée un MqttService. La factory (MqttService.create()) est
  /// recommandée car elle initialise les StreamControllers en lazy.
  MqttService() {
    _connectionStateController = StreamController<MqttConnectionState>.broadcast();
    _telemetryController = StreamController<BoxTelemetry>.broadcast();
  }

  Future<void> initialize({
    String? boxUid,
    String? mqttToken,
    bool force = false,
  }) async {
    if (!force && (_isInitializing || _initialized)) return;

    if (force && _initialized) {
      await _updatesSubscription?.cancel();
      try { _client.disconnect(); } catch (_) {}
      _initialized = false;
      _isInitializing = false;
      try { _telemetryController.close(); } catch (_) {}
      _telemetryController = StreamController<BoxTelemetry>.broadcast();
    }

    // boxUid is optional — a sensible default ("app") is used when missing,
    // and the token falls back to the dart-defined Flespi app token.
    _boxUid = boxUid ?? 'app';
    _mqttToken = mqttToken ?? AppConstants.flespiAppToken;

    if (_mqttToken == null || _mqttToken!.isEmpty) {
      throw ArgumentError(
        'MQTT token missing — pass one or define FLESPI_MQTT_APP_TOKEN at build time',
      );
    }

    _isInitializing = true;

    final clientId = 'aricie_${_boxUid}_${Random().nextInt(999999)}';

    try {
      _connectionStateController.add(MqttConnectionState.connecting);

      _client = createMqttClient();

      await _client.initialize(
        host: AppConstants.flespiHost,
        port: kIsWeb ? _wssPort : _tcpTlsPort,
        clientId: clientId,
        useWebSocket: kIsWeb,
        secure: !kIsWeb,
      );

      _client.setCredentials(
        username: _mqttToken!,
        // ponytail: Flespi tokens must be sent as both username and password.
        // Sending password="" makes some MQTT5 stacks encode a malformed
        // packet (Password flag set but length 0), which Flespi rejects
        // with badUsernameOrPassword. Mirror the token to the password.
        password: _mqttToken!,
      );

      _client.setOnConnected(() => _onConnected(_boxUid!));
      _client.setOnDisconnected(_onDisconnected);
      _client.setOnSubscribed(_onSubscribed);

      await _client.connect();

      await _updatesSubscription?.cancel();
      _updatesSubscription = _client.updates.listen(_processMessages);

      _initialized = true;
    } catch (e) {
      debugPrint('[MQTT5] Connexion impossible: $e');
      debugPrint('[MQTT5] boxUid=$_boxUid tokenLength=${_mqttToken?.length}');

      _connectionStateController.add(MqttConnectionState.disconnected);

      _scheduleReconnect();
    } finally {
      _isInitializing = false;
    }
  }

  void _onConnected(String boxUid) {
    debugPrint('[MQTT5] Connecté');

    _connectionStateController.add(MqttConnectionState.connected);

    _client.subscribe(
      'aricie/v1/boxes/$boxUid/telemetry',
      MqttQos.atLeastOnce,
    );

    _client.subscribe(
      'aricie/v1/boxes/$boxUid/status',
      MqttQos.atLeastOnce,
    );
  }

  void _processMessages(List<MqttReceivedMessage<MqttMessage>>? messages) {
    if (messages == null) return;

    for (final received in messages) {
      final topic = received.topic;
      final message = received.payload as MqttPublishMessage;
      final payloadBuffer = message.payload.message;

      if (payloadBuffer == null) {
        debugPrint('[MQTT5] Payload null sur topic: $topic');
        continue;
      }

      final payload = String.fromCharCodes(payloadBuffer);

      if (topic == null) continue;
      final parts = topic.split('/');
      final boxIndex = parts.indexOf('boxes');
      final boxUid = boxIndex >= 0 && parts.length > boxIndex + 1
          ? parts[boxIndex + 1]
          : null;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;

        final telemetry = BoxTelemetry.fromJson(
          json,
          boxUid: boxUid,
        );

        _latestTelemetry = telemetry;
        _telemetryController.add(telemetry);
        debugPrint('[MQTT5] Télémétrie reçue: temp=${telemetry.temperature}°C, hum=${telemetry.humidity}%');
      } catch (e) {
        debugPrint('[MQTT5] Erreur parsing télémétrie: $e');
      }
    }
  }

  void _onSubscribed(String topic) {
    debugPrint('[MQTT5] Abonné à $topic');
  }

  void _onDisconnected() {
    debugPrint('[MQTT5] Déconnecté');

    _initialized = false;
    _connectionStateController.add(MqttConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final boxUid = _boxUid;
    final mqttToken = _mqttToken;

    if (boxUid == null || mqttToken == null) return;

    Timer(const Duration(seconds: 5), () {
      initialize(
        boxUid: boxUid,
        mqttToken: mqttToken,
      );
    });
  }

  Future<void> dispose() async {
    _initialized = false;
    _client.disconnect();
    await _updatesSubscription?.cancel();
    await _connectionStateController.close();
    await _telemetryController.close();
  }
}
