import 'package:equatable/equatable.dart';

import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/shared/domain/load_status.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.unread = 0,
    this.error,
  });

  final LoadStatus status;
  final List<AppNotification> items;

  /// Drives the app-bar badge; kept separate so it can refresh without
  /// loading the whole inbox.
  final int unread;
  final String? error;

  NotificationsState copyWith({
    LoadStatus? status,
    List<AppNotification>? items,
    int? unread,
    String? error,
  }) =>
      NotificationsState(
        status: status ?? this.status,
        items: items ?? this.items,
        unread: unread ?? this.unread,
        error: error,
      );

  @override
  List<Object?> get props => [status, items, unread, error];
}
