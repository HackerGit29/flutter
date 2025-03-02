import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _notificationService.fetchNotifications();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<NotificationModel>>(
        valueListenable: _notificationService.notificationsStream,
        builder: (context, notifications, _) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text('Aucune notification'),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

// Update the NotificationTile class
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final NotificationService _notificationService = NotificationService();

  NotificationTile({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmer la suppression'),
              content: Text('Voulez-vous vraiment supprimer cette notification: "${notification.title}"?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Supprimer'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (_) {
        // Delete notification
        _notificationService.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${notification.title} supprimée'),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: () {
                // TODO: Implement undo functionality if needed
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          _notificationService.markAsRead(notification.id);
          _showNotificationDetails(context, notification);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead 
                ? null 
                : theme.colorScheme.primary.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getSeverityColor(notification.severity, theme).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getSeverityIcon(notification.severity),
                  color: _getSeverityColor(notification.severity, theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: notification.isRead 
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          timeago.format(notification.createdAt, locale: 'fr'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.description,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(BuildContext context, NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.description),
            const SizedBox(height: 8),
            Text(
              'Reçu ${timeago.format(notification.createdAt, locale: 'fr')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
}