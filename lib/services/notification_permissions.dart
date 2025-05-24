import 'dart:io';
import 'package:flutter/services.dart';

class NotificationPermissions {
  static const platform = MethodChannel('com.example.innovation/notifications');

  static Future<bool> canScheduleExactAlarms() async {
    if (Platform.isAndroid) {
      try {
        final result = await platform.invokeMethod('canScheduleExactAlarms');
        return result == true;
      } catch (e) {
        return false;
      }
    }
    return true; // Sur les autres plateformes, on suppose que c'est autorisé
  }
}