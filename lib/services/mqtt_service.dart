import 'dart:async';
import 'dart:math';
import 'package:aricie/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aricie/models/energy_data_model.dart';
import 'package:aricie/models/temperature_model.dart';
import 'package:aricie/models/humidity_model.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/src/typed_buffer.dart';

// Import the interface directly
import 'mqtt/mqtt_client_interface.dart';
// Import implementations directly (not conditionally)
import 'mqtt/mqtt_web.dart';
import 'mqtt/mqtt_native.dart';

class MqttService {
  // Topics constants
  static const String TOPIC_TEMPERATURE = 'sensors/temperature';
  static const String TOPIC_HUMIDITY = 'sensors/humidity';

  // Nouveaux topics pour les appareils
  static const String TOPIC_ENERGY_1 = 'energy/data/1';
  static const String TOPIC_ENERGY_2 = 'energy/data/2';
  static const String TOPIC_ENERGY_3 = 'energy/data/3';

  static const String TOPIC_CONTROL_1 = 'device/control/1';
  static const String TOPIC_CONTROL_2 = 'device/control/2';
  static const String TOPIC_CONTROL_3 = 'device/control/3';

  late MqttClientInterface _client;
  final List<double> _temperatureData = [];
  final List<double> _humidityData = [];

  // Données d'énergie par appareil
  final List<double> _energyData1 = [];
  final List<double> _energyData2 = [];
  final List<double> _energyData3 = [];

  // Statut des appareils
  String _deviceStatus1 = 'off';
  String _deviceStatus2 = 'off';
  String _deviceStatus3 = 'off';

  // Configuration de connexion
  final _wsUrl = 'mqtt://test.mosquitto.org:1883';
  final _clientId = 'dart_client_${Random().nextInt(1000)}';

  // Service de notification
  final _notificationService = NotificationService();
  
  // État précédent de la connexion pour éviter les notifications répétées
  MqttConnectionState? _previousConnectionState;

  // Controllers for streams
  final _connectionStateController =
      StreamController<MqttConnectionState>.broadcast();
  final _temperatureController = StreamController<TemperatureModel>.broadcast();
  final _humidityController = StreamController<double>.broadcast();

  // Controllers pour les données d'énergie par appareil
  final _energyDataController1 = StreamController<EnergyDataModel>.broadcast();
  final _energyDataController2 = StreamController<EnergyDataModel>.broadcast();
  final _energyDataController3 = StreamController<EnergyDataModel>.broadcast();

  // Controllers pour les statuts des appareils
  final _deviceStatusController1 = StreamController<String>.broadcast();
  final _deviceStatusController2 = StreamController<String>.broadcast();
  final _deviceStatusController3 = StreamController<String>.broadcast();

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
        _connectionStateController.add(MqttConnectionState.disconnected);
        _previousConnectionState = MqttConnectionState.disconnected;
        
        // Notification de déconnexion
        if (!kIsWeb) {
          _notificationService.showNotification(
            id: 3,
            title: 'Problème de connexion',
            body: 'Impossible de se connecter au broker MQTT. Vérifiez votre connexion internet.',
          );
        }
        
        _scheduleReconnect();
      }

      _client.updates.listen(_processMessage);
    }
  }

  void _onConnected() {
    print('✅ Connecté au broker MQTT via WebSocket');

    // Notifier l'UI que la connexion est établie
    _connectionStateController.add(MqttConnectionState.connected);
    
    // Si l'état précédent était déconnecté, envoyer une notification de reconnexion
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

    // S'abonner aux topics de température et humidité
    _client.subscribe(TOPIC_TEMPERATURE, 1);
    _client.subscribe(TOPIC_HUMIDITY, 1);

    // S'abonner aux topics d'énergie pour les 3 appareils
    _client.subscribe(TOPIC_ENERGY_1, 1);
    _client.subscribe(TOPIC_ENERGY_2, 1);
    _client.subscribe(TOPIC_ENERGY_3, 1);

    // S'abonner aux topics de contrôle pour les 3 appareils
    _client.subscribe(TOPIC_CONTROL_1, 2);
    _client.subscribe(TOPIC_CONTROL_2, 2);
    _client.subscribe(TOPIC_CONTROL_3, 2);
  }

  // Streams
  Stream<MqttConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<TemperatureModel> get temperatureStream =>
      _temperatureController.stream;
  Stream<double> get humidityStream => _humidityController.stream;

  // Streams pour les données d'énergie par appareil
  Stream<EnergyDataModel> get energyDataStream1 =>
      _energyDataController1.stream;
  Stream<EnergyDataModel> get energyDataStream2 =>
      _energyDataController2.stream;
  Stream<EnergyDataModel> get energyDataStream3 =>
      _energyDataController3.stream;

  // Streams pour les statuts des appareils
  Stream<String> get deviceStatusStream1 => _deviceStatusController1.stream;
  Stream<String> get deviceStatusStream2 => _deviceStatusController2.stream;
  Stream<String> get deviceStatusStream3 => _deviceStatusController3.stream;

  // Alias pour la compatibilité avec le code existant
  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  void _processMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (messages == null) return;

    for (var message in messages) {
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload as Uint8Buffer,
      );

      // Traitement des messages selon le topic
      if (message.topic == TOPIC_TEMPERATURE) {
        _handleTemperature(payload);
      } else if (message.topic == TOPIC_HUMIDITY) {
        _handleHumidity(payload);
      } else if (message.topic == TOPIC_ENERGY_1) {
        _handleEnergy(payload, 1);
      } else if (message.topic == TOPIC_ENERGY_2) {
        _handleEnergy(payload, 2);
      } else if (message.topic == TOPIC_ENERGY_3) {
        _handleEnergy(payload, 3);
      } else if (message.topic == TOPIC_CONTROL_1) {
        _handleControlCommand(payload, 1);
      } else if (message.topic == TOPIC_CONTROL_2) {
        _handleControlCommand(payload, 2);
      } else if (message.topic == TOPIC_CONTROL_3) {
        _handleControlCommand(payload, 3);
      }
    }
  }

  void _handleTemperature(String payload) {
    final value = double.tryParse(payload);
    if (value != null) {
      _temperatureData.add(value);
      print('Température reçue: $value°C');

      // Créer un modèle de température et l'envoyer dans le stream
      final tempModel = TemperatureModel(
        id: _temperatureData.length,
        temperature: value,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _temperatureController.add(tempModel);
    }
  }

  void _handleHumidity(String payload) {
    final value = double.tryParse(payload);
    if (value != null) {
      _humidityData.add(value);
      print('Humidité reçue: $value%');
      _humidityController.add(value);
    }
  }

  void _handleEnergy(String payload, int deviceId) {
    final value = double.tryParse(payload);
    if (value != null) {
      print('Consommation appareil $deviceId reçue: $value W');

      // Stocker la valeur dans la liste appropriée
      switch (deviceId) {
        case 1:
          _energyData1.add(value);
          break;
        case 2:
          _energyData2.add(value);
          break;
        case 3:
          _energyData3.add(value);
          break;
      }

      // Créer un modèle d'énergie
      final energyModel = EnergyDataModel(
        id: deviceId,
        totalDay: value,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Envoyer le modèle dans le stream approprié
      switch (deviceId) {
        case 1:
          _energyDataController1.add(energyModel);
          break;
        case 2:
          _energyDataController2.add(energyModel);
          break;
        case 3:
          _energyDataController3.add(energyModel);
          break;
      }
    }
  }

  void _handleControlCommand(String payload, int deviceId) {
    print('Commande reçue pour appareil $deviceId: $payload');

    // Mettre à jour le statut de l'appareil approprié
    final status = payload.toLowerCase();

    switch (deviceId) {
      case 1:
        _deviceStatus1 = status;
        _deviceStatusController1.add(status);
        break;
      case 2:
        _deviceStatus2 = status;
        _deviceStatusController2.add(status);
        break;
      case 3:
        _deviceStatus3 = status;
        _deviceStatusController3.add(status);
        break;
    }

    if (status == 'on') {
      print('Appareil $deviceId activé');
    } else if (status == 'off') {
      print('Appareil $deviceId désactivé');
    }
  }

  Future<void> sendControlCommand(String action, int deviceId) async {
    if (!['on', 'off'].contains(action.toLowerCase())) return;

    String topic;
    switch (deviceId) {
      case 1:
        topic = TOPIC_CONTROL_1;
        break;
      case 2:
        topic = TOPIC_CONTROL_2;
        break;
      case 3:
        topic = TOPIC_CONTROL_3;
        break;
      default:
        return; // Appareil invalide
    }

    _client.publish(
      topic,
      action.toLowerCase(),
      2, // QoS 2 = exactlyOnce
      retain: false,
    );

    print('Commande "$action" envoyée à l\'appareil $deviceId');
  }

  void _onSubscribed(String topic) {
    print('Abonné au topic: $topic');
  }

  void _onDisconnected() {
    print('Déconnecté du broker');
    _connectionStateController.add(MqttConnectionState.disconnected);
    
    // Notification de déconnexion seulement si l'état précédent était connecté
    if (_previousConnectionState == MqttConnectionState.connected) {
      if (!kIsWeb) {
        _notificationService.showNotification(
          id: 2,
          title: 'Connexion interrompue',
          body: 'La connexion avec le broker MQTT s\'est interrompue. Tentative de reconnexion en cours...',
        );
      }
    }
    
    _previousConnectionState = MqttConnectionState.disconnected;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Timer(const Duration(seconds: 5), () {
      print('Tentative de reconnexion...');
      _connectionStateController.add(MqttConnectionState.connecting);
      initialize();
    });
  }

  // Getters pour les données
  List<double> get temperatureData => _temperatureData;
  List<double> get humidityData => _humidityData;

  // Getters pour les données d'énergie par appareil
  List<double> get energyData1 => _energyData1;
  List<double> get energyData2 => _energyData2;
  List<double> get energyData3 => _energyData3;

  // Getters pour les statuts des appareils
  String get deviceStatus1 => _deviceStatus1;
  String get deviceStatus2 => _deviceStatus2;
  String get deviceStatus3 => _deviceStatus3;
}

// Exemple d'utilisation
void main() async {
  final mqttService = MqttService();
  await mqttService.initialize();

  // Send control command to device
  mqttService.sendControlCommand('off', 1); // Device 1
  mqttService.sendControlCommand('off', 2); // Device 2
  mqttService.sendControlCommand('off', 3); // Device 3
}
