import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../screens/notifications_screen.dart';

/// Reusable Notification Bell Icon with Realtime Unread Count Badge (Issue #5)
class NotificationBellIcon extends StatelessWidget {
  final Color iconColor;
  final double iconSize;
  final Color badgeColor;
  final String? userId;

  const NotificationBellIcon({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 22.0,
    this.badgeColor = const Color(0xFF00FF88),
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final uid = (userId != null && userId!.isNotEmpty)
        ? userId!
        : (SupabaseService.client.auth.currentUser?.id ?? '');

    return StreamBuilder<int>(
      stream: NotificationService().getUnreadCountStream(uid),
      initialData: NotificationService().unreadCountNotifier.value,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              '$unreadCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF05080D),
              ),
            ),
            backgroundColor: badgeColor,
            child: Icon(
              Icons.notifications_outlined,
              color: iconColor,
              size: iconSize,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
