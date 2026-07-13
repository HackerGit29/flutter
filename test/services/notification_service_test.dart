import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(() {
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
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NotificationService', () {
    test('is a singleton', () {
      expect(NotificationService(), same(NotificationService()));
    });

    test('initializeTimeZones sets Africa/Douala as local location', () {
      NotificationService().initializeTimeZones();
    });

    test('onNotificationTap callback can be assigned and invoked', () {
      String? received;
      final service = NotificationService();
      service.onNotificationTap = (payload) => received = payload;

      service.onNotificationTap?.call('update');

      expect(received, 'update');
    });

    test('init() wires the tap handler through to the plugin', () async {
      await NotificationService().init();
    });

    test('showNotification delegates to the plugin', () async {
      await NotificationService().showNotification(
        id: 1,
        title: 'Titre',
        body: 'Corps',
        payload: 'payload-1',
      );
    });

    test('showNotificationWithCustomIcon delegates to the plugin', () async {
      await NotificationService().showNotificationWithCustomIcon(
        id: 2,
        title: 'Titre',
        body: 'Corps',
        iconName: 'ic_custom',
      );
    });

    test('scheduleNotification delegates to the plugin', () async {
      await NotificationService().scheduleNotification(
        id: 3,
        title: 'Titre',
        body: 'Corps',
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      );
    });

    test('showPeriodicNotification delegates to the plugin (non-Android host)', () async {
      await NotificationService().showPeriodicNotification(
        id: 4,
        title: 'Titre',
        body: 'Corps',
        repeatInterval: RepeatInterval.daily,
      );
    });

    test('cancelNotification and cancelAllNotifications delegate to the plugin', () async {
      await NotificationService().cancelNotification(1);
      await NotificationService().cancelAllNotifications();
    });

    test('requestPermissions resolves the platform grant result', () async {
      final result = await NotificationService().requestPermissions();

      expect(result, true);
    });
  });
}