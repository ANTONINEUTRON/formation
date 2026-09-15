import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';

enum AgentStatus { active, idle }

/// Card displayed in the agent list tab for a single agent.
class AgentCard extends StatelessWidget {
  const AgentCard({
    super.key,
    required this.id,
    required this.name,
    required this.avatarIcon,
    required this.status,
  });

  final String id;
  final String name;
  final IconData avatarIcon;
  final AgentStatus status;

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.chat_outlined, color: AppColors.textPrimary),
              title: const Text('Open Chat'),
              onTap: () {
                Navigator.pop(context);
                context.router
                    .push(AgentChatRoute(agentId: id, agentName: name));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.textPrimary),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.router
                    .push(AgentConfigRoute(agentId: id, agentName: name));
              },
            ),
            ListTile(
              leading: Icon(
                status == AgentStatus.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: AppColors.warning,
              ),
              title: Text(status == AgentStatus.active
                  ? 'Pause Agent'
                  : 'Resume Agent'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(status == AgentStatus.active
                        ? 'Agent paused'
                        : 'Agent resumed'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.analytics_outlined, color: AppColors.primary),
              title: const Text('View Reports'),
              onTap: () {
                Navigator.pop(context);
                context.router.push(const ReportsRoute());
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete Agent',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Agent'),
        content: Text(
            'Are you sure you want to delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Agent deleted'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = status == AgentStatus.active;

    return GestureDetector(
      onTap: () =>
          context.router.push(AgentChatRoute(agentId: id, agentName: name)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                avatarIcon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.success
                              : AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'Active' : 'Idle',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action
            IconButton(
              icon: const Icon(Icons.more_vert),
              color: AppColors.textMuted,
              onPressed: () => _showMenu(context),
            ),
          ],
        ),
      ),
    );
  }
}
