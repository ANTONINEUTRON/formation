import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/empty_state.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/notifications/ui/cubits/notifications_cubit.dart';
import 'package:formation/features/notifications/ui/cubits/notifications_state.dart';
import 'package:formation/features/notifications/ui/widgets/notification_tile.dart';
import 'package:formation/features/shared/domain/load_status.dart';

/// Notification inbox. Tapping one marks it read and, when it carries a
/// league, opens that league.
@RoutePage()
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // The cubit is provided app-wide so the bell badge and this inbox stay in
    // step; opening the page just refreshes it.
    context.read<NotificationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) => const _NotificationsView();
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  void _open(BuildContext context, AppNotification notification) {
    context.read<NotificationsCubit>().markRead(notification);
    final leagueId = notification.leagueId;
    if (leagueId != null) {
      context.router.push(LeagueDetailRoute(leagueId: leagueId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (a, b) => a.items != b.items,
            builder: (context, state) {
              final hasUnread = state.items.any((n) => !n.read);
              return TextButton(
                onPressed: hasUnread ? cubit.markAllRead : null,
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.status == LoadStatus.initial ||
              (state.status == LoadStatus.loading && state.items.isEmpty)) {
            return const LoadingIndicator();
          }
          if (state.status == LoadStatus.failure && state.items.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_off,
              message: state.error ?? 'Could not load notifications.',
              actionLabel: 'Retry',
              onAction: cubit.load,
            );
          }
          if (state.items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              message: 'Nothing yet. You will hear from us when your daily '
                  'points land or a league starts, settles or gains a member.',
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => NotificationTile(
                notification: state.items[i],
                onTap: () => _open(context, state.items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}
