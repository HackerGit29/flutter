import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'mqtt_client_interface.dart';

class MqttNativeClient implements MqttClientInterface {
  late MqttServerClient _client;
  late String _url;
  late String _clientId;
  final _updatesController = StreamController<List<dynamic>>.broadcast();

  
  @override
  Future<void> initialize(String url, String clientId) async {
    // For native clients, we need to extract the host without the protocol
    String host = url;
    int port = 1883;
    
    // Handle different URL formats
    if (url.startsWith('mqtt://')) {
      host = url.replaceAll('mqtt://', '');
      
      // Extract port if specified
      if (host.contains(':')) {
        final parts = host.split(':');
        host = parts[0];
        port = int.parse(parts[1]);
      }
    } else if (url.startsWith('ws://')) {
      // For WebSocket URLs, convert to TCP for native clients
      host = url.replaceAll('ws://', '');
      
      // Extract port if specified
      if (host.contains(':')) {
        final parts = host.split(':');
        host = parts[0];
        port = int.parse(parts[1]);
      }
    }
    
    _url = host;
    _clientId = clientId;
    _client = MqttServerClient(_url, _clientId);
    _client.port = port;
    _client.logging(on: false);
    _client.setProtocolV311();
    _client.keepAlivePeriod = 30;
    _client.connectTimeoutPeriod = 5000;
  }
  
  @override
  Future<void> connect() async {
    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    try {
      await _client.connect();
    } catch (e) {
      print('Erreur de connexion: $e');
      rethrow;
    }
  }
  
  @override
  void subscribe(String topic, int qos) {
    _client.subscribe(topic, MqttQos.values[qos]);
  }
  
  @override
  void publish(String topic, String message, int qos, {bool retain = false}) {
    final builder = MqttClientPayloadBuilder()
      ..addString(message);
    
    _client.publishMessage(
      topic,
      MqttQos.values[qos],
      builder.payload!,
      retain: retain,
    );
  }
  
  @override
  Stream<List<MqttReceivedMessage<MqttMessage?>>?> get updates => 
      _updatesController.stream.map((data) => 
          data.map((item) => MqttReceivedMessage<MqttMessage?>('', item as MqttMessage?)).toList()
      );
  
  @override
  void setOnConnected(Function onConnected) {
    _client.onConnected = onConnected as void Function();
  }
  
  @override
  void setOnDisconnected(Function onDisconnected) {
    _client.onDisconnected = onDisconnected as void Function();
  }
  
  @override
  void setOnSubscribed(Function(String) onSubscribed) {
    _client.onSubscribed = onSubscribed;
  }
}