import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

enum MqttConnectionState { connected, connecting, disconnected }

class MqttService {
  static final MqttService _instance = MqttService._internal();

  factory MqttService() {
    return _instance;
  }

  MqttService._internal();

  final _connectionStateController =
      StreamController<MqttConnectionState>.broadcast();
  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  MqttBrowserClient? _client;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  Future<void> initialize() async {
    await connect();
  }

  Future<bool> connect() async {
    if (_isConnecting) return false;

    _isConnecting = true;
    _connectionStateController.add(MqttConnectionState.connecting);

    try {
      // Use MqttBrowserClient for web with WebSocket URL
      _client = MqttBrowserClient(
        'ws://localhost:9001/mqtt', // WebSocket endpoint, typically on port 9001
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
      );

      _client!.keepAlivePeriod = 60;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;

      // Set logging for debugging
      _client!.logging(on: true);
      _client!.setProtocolV311();
      _client!.websocketProtocols = ['mqtt'];

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(
            'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
          )
          .withWillTopic('willtopic')
          .withWillMessage('Will message')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _connectionStateController.add(MqttConnectionState.connected);
        _isConnecting = false;
        return true;
      } else {
        _client!.disconnect();
        _connectionStateController.add(MqttConnectionState.disconnected);
        _isConnecting = false;
        _scheduleReconnect();
        return false;
      }
    } catch (e) {
      debugPrint('MQTT connection failed: $e');
      _connectionStateController.add(MqttConnectionState.disconnected);
      _isConnecting = false;
      _scheduleReconnect();
      return false;
    }
  }

  void _onConnected() {
    debugPrint('MQTT client connected');
    _connectionStateController.add(MqttConnectionState.connected);

    // Subscribe to topics
    _client!.subscribe('home/devices/#', MqttQos.atLeastOnce);
  }

  void _onDisconnected() {
    debugPrint('MQTT client disconnected');
    _connectionStateController.add(MqttConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) {
    debugPrint('Subscription confirmed for topic $topic');
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
        connect();
      }
    });
  }

  Future<void> publishMessage(String topic, String message) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      await connect();
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    _client?.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: false,
    );
  }

  Stream<List<MqttReceivedMessage<MqttMessage>>>? get updates =>
      _client?.updates;

  void dispose() {
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _connectionStateController.close();
  }
}
