import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aricie/models/energy_data_model.dart';
import 'package:aricie/models/temperature_model.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/src/typed_buffer.dart';

// Import the interface directly
import 'mqtt/mqtt_client_interface.dart';
// Import implementations directly (not conditionally)
import 'mqtt/mqtt_web.dart';
import 'mqtt/mqtt_native.dart';


class MqttService {
  static const String TOPIC_TEMPERATURE = 'sensors/temperature';
  static const String TOPIC_HUMIDITY = 'sensors/humidity';
  static const String TOPIC_ENERGY = 'energy/data';
  static const String TOPIC_CONTROL = 'device/control';

  late MqttClientInterface _client;
  final List<double> _temperatureData = [];
  final List<double> _humidityData = [];
  final List<double> _energyData = [];
  String _deviceStatus = 'off';

  // Configuration de connexion
  final _wsUrl = 'mqtt://test.mosquitto.org:1883';
  final _clientId = 'dart_client_${Random().nextInt(1000)}';
  
  // Controllers for streams
  final _connectionStateController = StreamController<MqttConnectionState>.broadcast();
  final _temperatureController = StreamController<TemperatureModel>.broadcast();
  final _humidityController = StreamController<double>.broadcast();
  final _energyDataController = StreamController<EnergyDataModel>.broadcast();
  
  Future<void> initialize() async {
    // Création du client approprié selon la plateforme
    if (kIsWeb) {
      // Sur web, soit utiliser un client stub, soit désactiver la fonctionnalité
      _client = MqttWebClient();
      print('MQTT: Fonctionnalité limitée sur le web');
    } else {
      // Sur mobile, utiliser le client natif
      _client = MqttNativeClient();
      
      // Initialisation du client
      await _client.initialize(_wsUrl, _clientId);
      
      // Configuration des gestionnaires d'événements
      _client.setOnConnected(_onConnected);
      _client.setOnDisconnected(_onDisconnected);
      _client.setOnSubscribed(_onSubscribed);
      
      try {
        await _client.connect();
      } catch (e) {
        print('Erreur de connexion: $e');
        _scheduleReconnect();
      }
  
      _client.updates.listen(_processMessage as void Function(List event)?);
    }
  }

  void _onConnected() {
    print('✅ Connecté au broker MQTT via WebSocket');
    _client.subscribe(TOPIC_TEMPERATURE, 1); 
    _client.subscribe(TOPIC_HUMIDITY, 1);
    _client.subscribe(TOPIC_ENERGY, 1);
    _client.subscribe(TOPIC_CONTROL, 2); 
  }
  
  // Streams
  Stream<MqttConnectionState> get connectionState => _connectionStateController.stream;
  Stream<TemperatureModel> get temperatureStream => _temperatureController.stream;
  Stream<double> get humidityStream => _humidityController.stream;
  Stream<EnergyDataModel> get energyDataStream => _energyDataController.stream;
  Stream<MqttConnectionState> get connectionStateStream => _connectionStateController.stream;

  void _processMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (messages == null) return;

    for (var message in messages) {
      final payload = MqttPublishPayload.bytesToStringAsString(
          message.payload as Uint8Buffer);

      switch (message.topic) {
        case TOPIC_TEMPERATURE:
          _handleTemperature(payload);
          break;
        case TOPIC_HUMIDITY:
          _handleHumidity(payload);
          break;
        case TOPIC_ENERGY:
          _handleEnergy(payload);
          break;
        case TOPIC_CONTROL:
          _handleControlCommand(payload);
          break;
      }
    }
  }

  void _handleTemperature(String payload) {
    final value = double.tryParse(payload);
    if (value != null) {
      _temperatureData.add(value);
      print('🌡️ Température reçue: $value°C');
    }
  }

  void _handleHumidity(String payload) {
    final value = double.tryParse(payload);
    if (value != null) {
      _humidityData.add(value);
      print('💧 Humidité reçue: $value%');
    }
  }

  void _handleEnergy(String payload) {
    final value = double.tryParse(payload);
    if (value != null) {
      _energyData.add(value);
      print('⚡ Consommation reçue: $value W');
    }
  }

  void _handleControlCommand(String payload) {
    print('📥 Commande reçue: $payload');
    _deviceStatus = payload.toLowerCase();
    
    if (_deviceStatus == 'on') {
      print('🚀 Dispositif activé');
    } else if (_deviceStatus == 'off') {
      print('🛑 Dispositif désactivé');
    }
  }

  Future<void> sendControlCommand(String action) async {
    if (!['on', 'off'].contains(action.toLowerCase())) return;
    
    _client.publish(
      TOPIC_CONTROL,
      action.toLowerCase(),
      2, // QoS 2 = exactlyOnce
      retain: false,
    );

    print('📤 Commande "$action" envoyée');
  }

  void _onSubscribed(String topic) {
    print('📡 Abonné au topic: $topic');
  }

  void _onDisconnected() {
    print('⚠️ Déconnecté du broker');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Timer(const Duration(seconds: 5), () {
      print('♻️ Tentative de reconnexion...');
      initialize();
    });
  }

  // Getters pour les données
  List<double> get temperatureData => _temperatureData;
  List<double> get humidityData => _humidityData;
  List<double> get energyData => _energyData;
  String get deviceStatus => _deviceStatus;
}


// Exemple d'utilisation
void main() async {
  final mqttService = MqttService();
  await mqttService.initialize();

  // Simulation d'envoi de commande après 10 secondes
  Timer(const Duration(seconds: 10), () {
    mqttService.sendControlCommand('on');
  });
}
