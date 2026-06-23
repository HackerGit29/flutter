import 'dart:async';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_browser_client.dart';

import 'mqtt5_client_interface.dart';

class Mqtt5WebClient implements Mqtt5ClientInterface {
  late MqttBrowserClient _client;

  late String _clientId;
  String? _username;
  String _password = '';

  @override
  Future<void> initialize({
    required String host,
    required int port,
    required String clientId,
    required bool useWebSocket,
    required bool secure,
  }) async {
    _clientId = clientId;

    _client = MqttBrowserClient.withPort(
      host,
      clientId,
      port,
    );

    _client.logging(on: false);
    _client.keepAlivePeriod = 30;
  }

  @override
  void setCredentials({
    required String username,
    String password = '',
  }) {
    _username = username;
    _password = password;
  }

  @override
  Future<void> connect() async {
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .authenticateAs(_username ?? '', _password);

    _client.connectionMessage = connMessage;

    await _client.connect();
  }

  @override
  void subscribe(String topic, MqttQos qos) {
    _client.subscribe(topic, qos);
  }

  @override
  void publish(
    String topic,
    String message,
    MqttQos qos, {
    bool retain = false,
  }) {
    final builder = MqttPayloadBuilder();
    builder.addString(message);

    _client.publishMessage(
      topic,
      qos,
      builder.payload!,
      retain: retain,
    );
  }

  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>> get updates {
    return _client.updates;
  }

  @override
  void setOnConnected(void Function() onConnected) {
    _client.onConnected = onConnected;
  }

  @override
  void setOnDisconnected(void Function() onDisconnected) {
    _client.onDisconnected = onDisconnected;
  }

  @override
  void setOnSubscribed(void Function(String topic) onSubscribed) {
    _client.onSubscribed = (subscription) =>
        onSubscribed(subscription.topic.toString());
  }

  @override
  void disconnect() {
    _client.disconnect();
  }
}
