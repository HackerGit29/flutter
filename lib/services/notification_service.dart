import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'notification_permissions.dart'; // Importe la nouvelle classe

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Singleton pattern
  factory NotificationService() => _instance;

  NotificationService._internal() {
    _initNotifications();
  }

  void initializeTimeZones() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Douala'));
  }

  Future<void> _initNotifications() async {
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification cliquée: ${response.payload}');
        },
      );
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'innovation_channel',
      'Innovation Notifications',
      channelDescription: 'Notifications pour l\'application Innovation',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> showNotificationWithCustomIcon({
    required int id,
    required String title,
    required String body,
    required String iconName,
    String? payload,
  }) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      'innovation_channel',
      'Innovation Notifications',
      channelDescription: 'Notifications pour l\'application Innovation',
      importance: Importance.max,
      priority: Priority.high,
      icon: iconName,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'innovation_channel',
      'Innovation Notifications',
      channelDescription: 'Notifications pour l\'application Innovation',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      // matchDateTimeComponents: DateTimeComponents.time, // Active si notification récurrente
    );
  }

  Future<void> showPeriodicNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'innovation_channel',
      'Innovation Notifications',
      channelDescription: 'Notifications pour l\'application Innovation',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);
    
    // Vérifier l'autorisation pour les alarmes exactes
    bool useExactAlarm = true;
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      if (androidInfo.version.sdkInt >= 31) { // Android 12 (API 31) ou supérieur
        // Vérifier si l'autorisation est accordée
        final hasPermission = await NotificationPermissions.canScheduleExactAlarms();
        
        if (!hasPermission) {
          // Si l'autorisation n'est pas accordée, ouvrir les paramètres
          const intent = AndroidIntent(
            action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          );
          await intent.launch();
          
          // Attendre que l'utilisateur revienne et vérifier à nouveau
          await Future.delayed(const Duration(seconds: 2));
          useExactAlarm = await NotificationPermissions.canScheduleExactAlarms();
        }
      }
    }

    // Utiliser le mode exact seulement si autorisé, sinon fallback sur inexact
    await _flutterLocalNotificationsPlugin.periodicallyShow(
      id,
      title,
      body,
      repeatInterval,
      platformDetails,
      androidScheduleMode: useExactAlarm 
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final androidImpl = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      
      // Demander l'autorisation pour les alarmes exactes sur Android 12+
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        if (androidInfo.version.sdkInt >= 31) {
          const intent = AndroidIntent(
            action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          );
          await intent.launch();
        }
      }
      
      return granted ?? false;
    }

    return false;
  }
}
