import 'package:shared_preferences/shared_preferences.dart';

/// Persistance des préférences de notification de l'utilisateur.
///
/// Volontairement sans effet de bord (pas de planification ici) pour rester
/// testable : la planification/annulation réelle est faite par l'UI / `main`
/// via [NotificationService], en lisant ces préférences.
class NotificationPreferences {
  static const int dailyReminderId = 1;
  static const String _dailyReminderKey = 'notif_daily_reminder_enabled';

  /// Le rappel quotidien est activé par défaut.
  Future<bool> isDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dailyReminderKey) ?? true;
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyReminderKey, enabled);
  }
}
