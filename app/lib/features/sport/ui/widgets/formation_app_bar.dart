import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/notifications/ui/cubits/notifications_cubit.dart';
import 'package:formation/features/notifications/ui/cubits/notifications_state.dart';

/// App bar shared by the three sport pages: title plus Reports,
/// Notifications and Profile actions.
class FormationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FormationAppBar({required this.title, this.bottom, super.key});

  final String title;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      bottom: bottom,
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          onPressed: () => context.router.push(const ReportsRoute()),
          tooltip: 'Reports',
        ),
        const _NotificationsAction(),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.router.push(const ProfileRoute()),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.18),
              child: const Icon(Icons.person, size: 18, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// The bell, with an unread badge fed by [NotificationsCubit].
class _NotificationsAction extends StatelessWidget {
  const _NotificationsAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      buildWhen: (a, b) => a.unread != b.unread,
      builder: (context, state) {
        return IconButton(
          onPressed: () => context.router.push(const NotificationsRoute()),
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (state.unread > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.unread > 9 ? '9+' : '${state.unread}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
