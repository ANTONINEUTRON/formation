import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';

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
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.router.push(const NotificationsRoute()),
          tooltip: 'Notifications',
        ),
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
