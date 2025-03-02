import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticInOut,
      ),
    );
    
    // Listen for changes in unread count
    _notificationService.unreadCount.addListener(_handleUnreadCountChanged);
  }
  
  void _handleUnreadCountChanged() {
    if (_notificationService.unreadCount.value > 0) {
      // Animate the badge when new notifications arrive
      _animationController.forward().then((_) => _animationController.reverse());
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _notificationService.unreadCount.removeListener(_handleUnreadCountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _notificationService.unreadCount,
      builder: (context, unreadCount, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: IconButton(
                icon: widget.child,
                onPressed: widget.onPressed,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}