import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';

abstract class MqttClientInterface {
  Future<void> initialize(String url, String clientId);
  Future<void> connect();
  void subscribe(String topic, int qos);
  void publish(String topic, String message, int qos, {bool retain = false});
  Stream<List<MqttReceivedMessage<MqttMessage?>>?> get updates; // Type corrigé
  void setOnConnected(Function onConnected);
  void setOnDisconnected(Function onDisconnected);
  void setOnSubscribed(Function(String) onSubscribed);
}