import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/agent/ui/widgets/agent_type_card.dart';
import 'package:symbians/gen/assets.gen.dart';

/// Agent type selector page - choose between native agent or import existing.
@RoutePage()
class AgentTypeSelectorPage extends StatelessWidget {
  const AgentTypeSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Agent'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Agent Type',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select how you want to create your trading agent',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Native Agent Option
            AgentTypeCard(
              title: 'Native Agent',
              description: 'Create a new AI-powered trading agent with custom strategies and risk management.',
              icon: Assets.brand.symbiansLogoNobg,
              isComingSoon: false,
              onTap: () {
                context.router.push(const CreateAgentRoute());
              },
            ),

            const SizedBox(height: 16),

            // Existing Agent Option
            AgentTypeCard(
              title: 'Import Existing Agent',
              description: 'Connect your existing trading bot or agent from another platform.',
              iconData: Icons.link,
              isComingSoon: true,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}
