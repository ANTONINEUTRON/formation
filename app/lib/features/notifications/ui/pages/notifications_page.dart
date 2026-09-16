import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' hide Notification;

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/domain/entity/notification.dart';
import 'package:symbians/features/notifications/ui/widgets/notification_empty_state.dart';
import 'package:symbians/features/notifications/ui/widgets/notification_tile.dart';

/// Notifications page - displays system and agent notifications.
@RoutePage()
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Notification> _notifications = [
    Notification(
      id: '1',
      type: NotificationType.alert,
      title: 'Duel invite',
      body: 'A player challenged you to a 24h Football duel.',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Notification(
      id: '2',
      type: NotificationType.trade,
      title: 'Hourly tick',
      body: 'Your Football team scored +41 points this hour.',
      time: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    Notification(
      id: '3',
      type: NotificationType.alert,
      title: 'Duel won',
      body: 'Your team finished +1.24% vs −0.31%. Trophy recorded.',
      time: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    Notification(
      id: '4',
      type: NotificationType.system,
      title: 'Welcome to Formation',
      body: 'Draft a team in any sport to join its global league.',
      time: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = Notification(
          id: _notifications[i].id,
          type: _notifications[i].type,
          title: _notifications[i].title,
          body: _notifications[i].body,
          time: _notifications[i].time,
          isRead: true,
        );
      }
    });
  }

  void _markRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final n = _notifications[index];
    if (n.isRead) return;
    setState(() {
      _notifications[index] = Notification(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        time: n.time,
        isRead: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.checklist_rtl),
              onPressed: _markAllRead,
              tooltip: 'Mark all read',
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? NotificationEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return NotificationTile(
                  notification: notif,
                  onTap: () => _markRead(notif.id),
                );
              },
            ),
    );
  }
}

