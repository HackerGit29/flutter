import 'package:shared_preferences/shared_preferences.dart';

class LocalDataSource {
  static const _sessionKey = 'user_session';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';

  Future<void> cacheSession(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getCachedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = prefs.getBool(_sessionKey) ?? false;
    return hasSession ? prefs.getString(_userIdKey) : null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
  }
}
