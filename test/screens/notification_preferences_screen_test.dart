import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aricie/screens/profile/notification_preferences_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'pendingNotificationRequests':
          return <Map<String, dynamic>>[];
        case 'requestNotificationsPermission':
          return true;
        case 'periodicallyShow':
          return null;
        case 'cancel':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget wrap() => const MaterialApp(home: NotificationPreferencesScreen());

  group('NotificationPreferencesScreen', () {
    testWidgets('shows a loading indicator then the daily reminder switch',
        (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Rappel quotidien de consommation'), findsOneWidget);
    });

    testWidgets('defaults the switch to enabled when no preference is stored',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final switchTile =
          tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, true);
    });

    testWidgets('toggling off shows a confirmation snackbar', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Rappel quotidien désactivé.'), findsOneWidget);

      final switchTile =
          tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, false);
    });

    testWidgets('starting disabled, toggling on shows the enabled confirmation snackbar',
        (tester) async {
      SharedPreferences.setMockInitialValues({'notif_daily_reminder_enabled': false});
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final switchTile =
          tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, false);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Rappel quotidien activé.'), findsOneWidget);
    });
  });
}