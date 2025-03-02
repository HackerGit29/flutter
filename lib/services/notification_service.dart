import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final _supabase = Supabase.instance.client;
  final List<NotificationModel> _notifications = [];
  final _notificationsController = ValueNotifier<List<NotificationModel>>([]);
  final _unreadCountController = ValueNotifier<int>(0);
  RealtimeChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // List to keep track of BuildContext for overlay notifications
  final List<BuildContext> _overlayContexts = [];

  // Singleton pattern
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _initNotifications();
  }

  ValueNotifier<List<NotificationModel>> get notificationsStream =>
      _notificationsController;

  ValueNotifier<int> get unreadCount => _unreadCountController;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);


   Future<void> playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
      // Fallback to default system sound or handle error silently
    }
  }


  Future<void> _initNotifications() async {
    // Initialize local notifications
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }

    // Load notification sound
    await _audioPlayer.setSource(AssetSource('sounds/notification.mp3'));

    // Get current user
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Fetch existing notifications
    await fetchNotifications();

    // Subscribe to real-time updates
    _subscribeToNotifications(user.id);
  }

  Future<void> fetchNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('alerts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _notifications.clear();
      _notifications.addAll(
        (response as List)
            .map((data) => NotificationModel.fromJson(data))
            .toList(),
      );

      _notificationsController.value = List.from(_notifications);

      // Update unread count
      _updateUnreadCount();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  void _updateUnreadCount() {
    final count =
        _notifications.where((notification) => !notification.isRead).length;
    _unreadCountController.value = count;
  }

  void _subscribeToNotifications(String userId) {
    _channel =
        _supabase
            .channel('schema-db-changes')
            .onPostgresChanges(
              schema: 'public',
              table: 'alerts',
              event: PostgresChangeEvent.insert,
              callback: (payload) {
                final newNotification = NotificationModel.fromJson(
                  payload.newRecord,
                );
                _handleNewNotification(newNotification);
              },
            )
            .onPostgresChanges(
              schema: 'public',
              table: 'alerts',
              event: PostgresChangeEvent.delete,
              callback: (payload) {
                final deletedId = payload.oldRecord['id'] as String?;
                if (deletedId != null) {
                  final index = _notifications.indexWhere(
                    (n) => n.id == deletedId,
                  );
                  if (index != -1) {
                    _notifications.removeAt(index);
                    _notificationsController.value = List.from(_notifications);
                    _updateUnreadCount();
                  }
                }
              },
            )
            .subscribe();
  }

  void _handleNewNotification(NotificationModel notification) {
    // Add to local list
    _notifications.insert(0, notification);
    _notificationsController.value = List.from(_notifications);

    // Update unread count
    _updateUnreadCount();

    // Play sound
    _audioPlayer.resume();

    // Show notification
    _showNotification(notification);
  }

  Future<void> _showNotification(NotificationModel notification) async {
    // Show in-app notification
    for (final context in _overlayContexts) {
      if (context.mounted) {
        _showOverlayNotification(context, notification);
      }
    }

    // Show system notification on mobile
    if (!kIsWeb) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'alerts_channel',
            'Alerts',
            channelDescription: 'Notifications for alerts',
            importance: Importance.max,
            priority: Priority.high,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.description,
        platformChannelSpecifics,
      );
    }
  }

  void registerContext(BuildContext context) {
    if (!_overlayContexts.contains(context)) {
      _overlayContexts.add(context);
    }
  }

  void unregisterContext(BuildContext context) {
    _overlayContexts.remove(context);
  }

  void _showOverlayNotification(
    BuildContext context,
    NotificationModel notification,
  ) {
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            left: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  entry?.remove();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(notification.severity, theme),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getSeverityIcon(notification.severity),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              notification.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          entry?.remove();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (entry?.mounted ?? false) {
        entry?.remove();
      }
    });
  }

  Color _getSeverityColor(String severity, ThemeData theme) {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      case 'warning':
        return Colors.amber;
      case 'info':
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'high':
        return Icons.error_outline;
      case 'medium':
        return Icons.warning_amber_outlined;
      case 'low':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_outlined;
      case 'info':
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final updatedNotification = _notifications[index].copyWith(
          isRead: true,
        );
        _notifications[index] = updatedNotification;
        _notificationsController.value = List.from(_notifications);

        // Update unread count
        _updateUnreadCount();

        // Update in database
        await _supabase
            .from('alerts')
            .update({'is_read': true})
            .eq('id', notificationId);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Supprimer d'abord de la base de données
      final response =
          await _supabase
              .from('alerts')
              .delete()
              .eq('id', notificationId)
              .select();

      // Si la suppression a réussi, mettre à jour la liste locale
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications.removeAt(index);
        _notificationsController.value = List.from(_notifications);
        _updateUnreadCount();
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      // Afficher un message d'erreur à l'utilisateur
      for (final context in _overlayContexts) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Impossible de supprimer la notification. Vérifiez vos permissions.',
              ),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      }
    }
  }

  void dispose() {
    _channel?.unsubscribe();
    _audioPlayer.dispose();
    _notificationsController.dispose();
    _unreadCountController.dispose();
  }
}
