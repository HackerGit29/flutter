class AppConstants {
  static const String appName = 'aricie';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mqttBrokerUrl = String.fromEnvironment(
    'MQTT_BROKER_URL',
    defaultValue: 'mqtt://test.mosquitto.org:1883',
  );
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int syncRateLimitPerMinute = 10;
  static const int adminActionRateLimitPerMinute = 5;
  static const Duration tokenRefreshMargin = Duration(minutes: 5);
}
