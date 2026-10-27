import 'package:aricie/services/notification_preferences.dart';
import 'package:aricie/services/notification_service.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Préférences de notification de l'utilisateur.
/// Pour l'instant : activation/désactivation du rappel quotidien de
/// consommation (notification locale périodique).
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _prefs = NotificationPreferences();
  final _notifications = NotificationService();

  bool _dailyReminder = true;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _prefs.isDailyReminderEnabled();
    if (!mounted) return;
    setState(() {
      _dailyReminder = enabled;
      _loading = false;
    });
  }

  Future<void> _onDailyReminderChanged(bool value) async {
    setState(() => _busy = true);

    await _prefs.setDailyReminderEnabled(value);

    if (value) {
      // (Re)planifie le rappel quotidien.
      await _notifications.requestPermissions();
      await _notifications.showPeriodicNotification(
        id: NotificationPreferences.dailyReminderId,
        title: 'Rappel quotidien',
        body: 'N\'oubliez pas de vérifier votre consommation d\'énergie',
        repeatInterval: RepeatInterval.daily,
      );
    } else {
      await _notifications.cancelNotification(
        NotificationPreferences.dailyReminderId,
      );
    }

    if (!mounted) return;
    setState(() {
      _dailyReminder = value;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Rappel quotidien activé.'
              : 'Rappel quotidien désactivé.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences de notification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: Text(
                      'Les notifications ne sont pas disponibles sur le web.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                SwitchListTile(
                  value: _dailyReminder,
                  onChanged: (_busy || kIsWeb) ? null : _onDailyReminderChanged,
                  secondary: const Icon(Icons.bolt_outlined),
                  title: const Text('Rappel quotidien de consommation'),
                  subtitle: const Text(
                    'Recevez chaque jour un rappel pour vérifier votre '
                    'consommation d\'énergie.',
                  ),
                ),
              ],
            ),
    );
  }
}
