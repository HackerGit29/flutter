import 'mqtt5_client_interface.dart';
import 'mqtt5_native.dart';

Mqtt5ClientInterface createMqttClient() => Mqtt5NativeClient();
