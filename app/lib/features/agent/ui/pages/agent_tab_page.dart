import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:symbians/core/constants/app_constants.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/agent/ui/widgets/agent_card.dart';

/// Agent tab - displays user's agents and their activities.
class AgentTabPage extends StatelessWidget {
  const AgentTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.router.push(const ReportsRoute()),
            tooltip: 'View Reports',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.router.push(const NotificationsRoute()),
            tooltip: 'Notifications',
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 85),
        child: FloatingActionButton(
          onPressed: () => context.router.push(const AgentTypeSelectorRoute()),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          child: const Icon(Icons.add),
        ),
      ),
      
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16,16,16,50),
        children: [
          // Dummy agent cards
          AgentCard(
            id: 'agent_1',
            name: 'Explorer Bot',
            avatarIcon: Icons.smart_toy,
            status: AgentStatus.active,
          ),
          const SizedBox(height: 12),
          AgentCard(
            id: 'agent_2',
            name: 'Trader Agent',
            avatarIcon: Icons.currency_exchange,
            status: AgentStatus.idle,
          ),
          const SizedBox(height: 12),
          AgentCard(
            id: 'agent_3',
            name: 'External Helper',
            avatarIcon: Icons.support_agent,
            status: AgentStatus.active,
          ),
        ],
      ),
    );
  }
}
