/// What produced a notification. Kept narrow on purpose: per-tick scoring is
/// deliberately not notified, so the bell stays worth looking at.
enum NotificationKind {
  points('points'),
  leagueStarted('league_started'),
  leagueSettled('league_settled'),
  leagueJoined('league_joined');

  const NotificationKind(this.apiValue);

  final String apiValue;

  static NotificationKind fromApi(String value) =>
      values.firstWhere((k) => k.apiValue == value, orElse: () => points);
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.fromApi(json['kind'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        data: json['data'] as Map<String, dynamic>?,
        read: json['read'] as bool? ?? false,
      );

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Deep-link payload, e.g. { "leagueId": "..." }.
  final Map<String, dynamic>? data;
  final bool read;

  String? get leagueId => data?['leagueId'] as String?;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        data: data,
        read: read ?? this.read,
      );
}
