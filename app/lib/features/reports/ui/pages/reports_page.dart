import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/reports/ui/widgets/feature_preview_card.dart';

/// Reports page - shows agent trading reports and insights.
@RoutePage()
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Reports Coming Soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your agent\'s performance, view trade history, PnL charts, and get AI-powered insights.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              // Feature preview cards
              FeaturePreviewCard(
                icon: Icons.show_chart,
                title: 'PnL Tracking',
                description: 'Daily, weekly, monthly performance',
              ),
              const SizedBox(height: 12),
              FeaturePreviewCard(
                icon: Icons.history,
                title: 'Trade History',
                description: 'Every trade with entry reasons',
              ),
              const SizedBox(height: 12),
              FeaturePreviewCard(
                icon: Icons.lightbulb_outline,
                title: 'AI Insights',
                description: 'Strategy improvement suggestions',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
