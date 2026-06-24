class AppConstants {
  static const String appName = 'aricie';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String supabaseServiceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');
  static const String flespiWorkerToken = String.fromEnvironment('FLESPI_MQTT_WORKER_TOKEN', defaultValue: '');
  static const String flespiAppToken = String.fromEnvironment('FLESPI_MQTT_APP_TOKEN', defaultValue: '');
  static const String flespiHost = String.fromEnvironment('FLESPI_MQTT_HOST', defaultValue: 'mqtt.flespi.io');
  static const String flespiTcpPort = String.fromEnvironment('FLESPI_MQTT_TCP_PORT', defaultValue: '8883');
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int syncRateLimitPerMinute = 10;
  static const int adminActionRateLimitPerMinute = 5;
  static const Duration tokenRefreshMargin = Duration(minutes: 5);
  static const String updateChannelId = 'update_channel';
  static const int updateNotificationId = 100;
}
