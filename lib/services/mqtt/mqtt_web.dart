import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
// Suppression de l'import problématique
// import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:typed_data/src/typed_buffer.dart';
import 'mqtt_client_interface.dart';

class MqttWebClient implements MqttClientInterface {
  // Utilisation d'une implémentation stub pour mobile
  // Cette classe sera utilisée uniquement sur le web, mais doit compiler sur mobile
  dynamic _client;
  late String _url;
  late String _clientId;
  final _updatesController = StreamController<List<dynamic>>.broadcast();
  
  @override
  Future<void> initialize(String url, String clientId) async {
    _url = url;
    _clientId = clientId;
    
    // Ne rien faire sur mobile
    // Sur web, ce code serait remplacé par l'implémentation réelle
  }
  
  @override
  Future<void> connect() async {
    // Ne rien faire sur mobile
    // Sur web, ce code serait remplacé par l'implémentation réelle
    print('Web MQTT client non disponible sur cette plateforme');
  }
  
  @override
  void subscribe(String topic, int qos) {
    // Ne rien faire sur mobile
  }
  
  @override
  void publish(String topic, String message, int qos, {bool retain = false}) {
    // Ne rien faire sur mobile
  }
  
  @override
  Stream<List<MqttReceivedMessage<MqttMessage?>>?> get updates => 
      _updatesController.stream.map((data) => 
          data.map((item) => MqttReceivedMessage<MqttMessage?>('', item as MqttMessage?)).toList()
      );
  
  @override
  void setOnConnected(Function onConnected) {
    // Ne rien faire sur mobile
  }
  
  @override
  void setOnDisconnected(Function onDisconnected) {
    // Ne rien faire sur mobile
  }
  
  @override
  void setOnSubscribed(Function(String) onSubscribed) {
    // Ne rien faire sur mobile
  }
}