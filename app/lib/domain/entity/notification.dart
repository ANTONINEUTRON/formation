
enum NotificationType { trade, alert, system }

class Notification {
  const Notification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
}

