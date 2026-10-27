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
  // Ports lus depuis la config de build : EMQX Serverless = 8883 (MQTT/TLS)
  // et 8084 (WSS, chemin /mqtt). Flespi utilisait 443 pour le WSS.
  static final int _tcpTlsPort = int.tryParse(AppConstants.mqttTcpPort) ?? 8883;
  static const int _wssPort = AppConstants.mqttWssPort;
  late Mqtt5ClientInterface _client;

  late StreamController<MqttConnectionState> _connectionStateController;
  late StreamController<BoxTelemetry> _telemetryController;
  late StreamController<Map<int, RelayState>> _relayStatesController;

  StreamSubscription? _updatesSubscription;

  BoxTelemetry? _latestTelemetry;
  Map<int, RelayState>? _latestRelayStates;

  bool _isInitializing = false;
  bool _initialized = false;

  String? _boxUid;
  String? _mqttUsername;
  String? _mqttPassword;

  Stream<MqttConnectionState> get connectionState =>
      _connectionStateController.stream;

  Stream<BoxTelemetry> get telemetryStream => _telemetryController.stream;

  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  BoxTelemetry? get latestTelemetry => _latestTelemetry;

  Stream<Map<int, RelayState>> get relayStatesStream =>
      _relayStatesController.stream;

  Map<int, RelayState>? get latestRelayStates => _latestRelayStates;

  /// Crée un MqttService. La factory (MqttService.create()) est
  /// recommandée car elle initialise les StreamControllers en lazy.
  MqttService() {
    _connectionStateController = StreamController<MqttConnectionState>.broadcast();
    _telemetryController = StreamController<BoxTelemetry>.broadcast();
    _relayStatesController = StreamController<Map<int, RelayState>>.broadcast();
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

    // boxUid is optional — a sensible default ("app") is used when missing.
    _boxUid = boxUid ?? 'app';
    // Credentials : soit passés explicitement (mqttToken = couple unique type
    // Flespi), soit lus dans la config de build MQTT_USERNAME / MQTT_PASSWORD
    // (repli automatique sur FLESPI_MQTT_APP_TOKEN, cf. AppConstants).
    _mqttUsername = mqttToken ?? AppConstants.mqttUsername;
    _mqttPassword = mqttToken ?? AppConstants.mqttPassword;

    if (_mqttUsername == null || _mqttUsername!.isEmpty) {
      throw ArgumentError(
        'MQTT credentials missing — define MQTT_USERNAME / MQTT_PASSWORD at build time '
        '(legacy: FLESPI_MQTT_APP_TOKEN)',
      );
    }

    _isInitializing = true;

    final clientId = 'aricie_${_boxUid}_${Random().nextInt(999999)}';

    try {
      _connectionStateController.add(MqttConnectionState.connecting);

      _client = createMqttClient();

      await _client.initialize(
        host: AppConstants.mqttHost,
        port: kIsWeb ? _wssPort : _tcpTlsPort,
        clientId: clientId,
        useWebSocket: kIsWeb,
        secure: !kIsWeb,
      );

      _client.setCredentials(
        username: _mqttUsername!,
        // Flespi : le token doit être envoyé en username ET password (un
        // password vide produit un paquet MQTT5 malformé, refusé avec
        // badUsernameOrPassword). AppConstants.mqttPassword retombe donc sur
        // le username quand MQTT_PASSWORD n'est pas défini.
        password: _mqttPassword!,
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
      debugPrint(
        '[MQTT5] boxUid=$_boxUid host=${AppConstants.mqttHost} '
        'userLength=${_mqttUsername?.length}',
      );

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

        final relayMap = <int, RelayState>{};
        for (final relay in telemetry.relays) {
          relayMap[relay.index] = relay;
        }
        _latestRelayStates = relayMap;
        _relayStatesController.add(relayMap);

        debugPrint('[MQTT5] Télémétrie reçue: temp=${telemetry.temperature}°C, hum=${telemetry.humidity}%, relais=${telemetry.relays.length}');
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

    if (boxUid == null) return;

    // initialize() sans credentials explicites : ils sont relus depuis la
    // config de build (MQTT_USERNAME / MQTT_PASSWORD).
    Timer(const Duration(seconds: 5), () {
      initialize(boxUid: boxUid);
    });
  }

  Future<void> dispose() async {
    _initialized = false;
    _client.disconnect();
    await _updatesSubscription?.cancel();
    await _connectionStateController.close();
    await _telemetryController.close();
    await _relayStatesController.close();
  }
}
