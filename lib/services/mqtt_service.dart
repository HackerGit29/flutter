import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:aricie/models/box_telemetry.dart';
import 'package:aricie/services/notification_service.dart';
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

  final _connectionStateController =
      StreamController<MqttConnectionState>.broadcast();

  final _telemetryController =
      StreamController<BoxTelemetry>.broadcast();

  final _notificationService = NotificationService();

  StreamSubscription? _updatesSubscription;

  MqttConnectionState? _previousConnectionState;
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

  Future<void> initialize({
    String? boxUid,
    String? mqttToken,
  }) async {
    if (_isInitializing || _initialized) return;

    // boxUid requis, token fallback sur celui de l'app mobile
    _boxUid = boxUid;
    _mqttToken = mqttToken ?? AppConstants.flespiAppToken;

    if (_boxUid == null || _mqttToken == null) {
      throw ArgumentError('Box UID and MQTT token are required');
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
        password: '',
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

      _connectionStateController.add(MqttConnectionState.disconnected);
      _previousConnectionState = MqttConnectionState.disconnected;

      _scheduleReconnect();
    } finally {
      _isInitializing = false;
    }
  }

  void _onConnected(String boxUid) {
    debugPrint('[MQTT5] Connecté');

    _connectionStateController.add(MqttConnectionState.connected);

    if (_previousConnectionState == MqttConnectionState.disconnected) {
      if (!kIsWeb) {
        _notificationService.showNotification(
          id: 4,
          title: 'Connexion rétablie',
          body: 'La connexion avec le broker MQTT a été rétablie.',
        );
      }
    }

    _previousConnectionState = MqttConnectionState.connected;

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

    if (_previousConnectionState == MqttConnectionState.connected) {
      if (!kIsWeb) {
        _notificationService.showNotification(
          id: 2,
          title: 'Connexion interrompue',
          body: 'Tentative de reconnexion en cours...',
        );
      }
    }

    _previousConnectionState = MqttConnectionState.disconnected;
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
