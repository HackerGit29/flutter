import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/services/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late NotificationPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = NotificationPreferences();
  });

  test('le rappel quotidien est activé par défaut', () async {
    expect(await prefs.isDailyReminderEnabled(), true);
  });

  test('désactiver puis relire renvoie false', () async {
    await prefs.setDailyReminderEnabled(false);
    expect(await prefs.isDailyReminderEnabled(), false);
  });

  test('réactiver renvoie true', () async {
    await prefs.setDailyReminderEnabled(false);
    await prefs.setDailyReminderEnabled(true);
    expect(await prefs.isDailyReminderEnabled(), true);
  });
}
