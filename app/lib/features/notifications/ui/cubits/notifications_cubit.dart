import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/utils/format.dart';
import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/notifications/ui/cubits/notifications_state.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/load_status.dart';

/// The notification inbox, plus the unread count behind the app-bar bell.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required FormationRepository repository})
      : _repository = repository,
        super(const NotificationsState()) {
    _changes = _repository.changes.listen((_) => refreshUnread());
  }

  final FormationRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final items = await _repository.getNotifications();
      if (isClosed) return;
      emit(NotificationsState(status: LoadStatus.success, items: items));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  /// Cheap poll for the badge, without pulling the whole inbox.
  Future<void> refreshUnread() async {
    try {
      final count = await _repository.getUnreadNotificationCount();
      if (!isClosed) emit(state.copyWith(unread: count));
    } catch (_) {
      // A badge is not worth surfacing an error for.
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.read) return;
    // Optimistic: the tile should not wait on a round trip to look read.
    emit(state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == notification.id) n.copyWith(read: true) else n,
      ],
      unread: (state.unread - 1).clamp(0, state.unread),
    ));
    try {
      await _repository.markNotificationRead(notification.id);
    } catch (_) {
      await load();
    }
  }

  Future<void> markAllRead() async {
    if (state.items.every((n) => n.read)) return;
    emit(state.copyWith(
      items: [for (final n in state.items) n.copyWith(read: true)],
      unread: 0,
    ));
    try {
      await _repository.markAllNotificationsRead();
    } catch (_) {
      await load();
    }
  }

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
