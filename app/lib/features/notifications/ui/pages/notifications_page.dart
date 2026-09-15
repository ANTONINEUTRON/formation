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
      type: NotificationType.trade,
      title: 'Trade Executed',
      body: 'Explorer Bot bought 12.5 SOL at \$142.30',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Notification(
      id: '2',
      type: NotificationType.alert,
      title: 'Price Alert',
      body: 'SOL crossed your target price of \$145.00',
      time: DateTime.now().subtract(const Duration(minutes: 23)),
    ),
    Notification(
      id: '3',
      type: NotificationType.trade,
      title: 'Trade Executed',
      body: 'Trader Agent sold 500 USDC for 3.48 SOL',
      time: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Notification(
      id: '4',
      type: NotificationType.alert,
      title: 'Agent Paused',
      body: 'Trader Agent paused due to daily loss limit reached.',
      time: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    Notification(
      id: '5',
      type: NotificationType.system,
      title: 'Strategy Adopted',
      body: '2 users adopted your "DCA Momentum" strategy this week.',
      time: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
    Notification(
      id: '6',
      type: NotificationType.system,
      title: 'Welcome to Symbians',
      body:
          'Your account is set up. Create your first AI agent to get started.',
      time: DateTime.now().subtract(const Duration(days: 1)),
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

