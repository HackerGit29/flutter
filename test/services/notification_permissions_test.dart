import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/services/notification_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.innovation/notifications');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NotificationPermissions.canScheduleExactAlarms', () {
    test('returns true when the platform channel is unavailable (non-Android)', () async {
      // On the host test platform (Linux/macOS/Windows), Platform.isAndroid
      // is false, so the method should short-circuit to true without ever
      // touching the channel.
      final result = await NotificationPermissions.canScheduleExactAlarms();

      expect(result, true);
    });
  });
}
