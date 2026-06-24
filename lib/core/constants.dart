class AppConstants {
  static const String appName = 'aricie';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int syncRateLimitPerMinute = 10;
  static const int adminActionRateLimitPerMinute = 5;
  static const Duration tokenRefreshMargin = Duration(minutes: 5);
  static const String updateChannelId = 'update_channel';
  static const int updateNotificationId = 100;
}
