class AppConstants {
  static const String appName = 'aricie';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String flespiAppToken = String.fromEnvironment('FLESPI_MQTT_APP_TOKEN', defaultValue: '');
  static const String flespiHost = String.fromEnvironment('FLESPI_MQTT_HOST', defaultValue: 'mqtt.flespi.io');
  static const String flespiTcpPort = String.fromEnvironment('FLESPI_MQTT_TCP_PORT', defaultValue: '8883');
  // ponytail: override via --dart-define=FLESPI_DEFAULT_BOX_UID=<uid> to point the
  // app at a specific hardware box (e.g. ESP32-A1B2C3D4) when the user has no
  // appliance bound yet. Empty default = keep the 'app' fallback.
  static const String flespiDefaultBoxUid = String.fromEnvironment('FLESPI_DEFAULT_BOX_UID', defaultValue: '');

  // Broker MQTT 5 (EMQX Cloud Serverless). Les noms `flespi*` ci-dessus restent
  // supportés en repli pour ne pas casser les builds existants : dès que
  // MQTT_HOST / MQTT_USERNAME / MQTT_PASSWORD sont passés en --dart-define,
  // ils prennent le dessus.
  static const String mqttHost = String.fromEnvironment(
    'MQTT_HOST',
    defaultValue: flespiHost,
  );
  static const String mqttTcpPort = String.fromEnvironment(
    'MQTT_TCP_PORT',
    defaultValue: flespiTcpPort,
  );
  static const String mqttUsername = String.fromEnvironment(
    'MQTT_USERNAME',
    defaultValue: flespiAppToken,
  );
  static const String mqttPassword = String.fromEnvironment(
    'MQTT_PASSWORD',
    defaultValue: mqttUsername,
  );
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int syncRateLimitPerMinute = 10;
  static const int adminActionRateLimitPerMinute = 5;
  static const Duration tokenRefreshMargin = Duration(minutes: 5);
  static const String updateChannelId = 'update_channel';
  static const int updateNotificationId = 100;
}
