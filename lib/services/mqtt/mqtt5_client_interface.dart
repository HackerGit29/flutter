import 'dart:async';
import 'package:mqtt5_client/mqtt5_client.dart';

abstract class Mqtt5ClientInterface {
  Future<void> initialize({
    required String host,
    required int port,
    required String clientId,
    required bool useWebSocket,
    required bool secure,
  });

  void setCredentials({
    required String username,
    String password = '',
  });

  Future<void> connect();

  void subscribe(String topic, MqttQos qos);

  void publish(
    String topic,
    String message,
    MqttQos qos, {
    bool retain = false,
  });

  Stream<List<MqttReceivedMessage<MqttMessage>>> get updates;

  void setOnConnected(void Function() onConnected);

  void setOnDisconnected(void Function() onDisconnected);

  void setOnSubscribed(void Function(String topic) onSubscribed);

  void disconnect();
}
