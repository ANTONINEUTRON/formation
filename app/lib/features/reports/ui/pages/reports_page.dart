import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/reports/ui/widgets/feature_preview_card.dart';

/// Reports page - portfolio analytics, coming soon (premium tier).
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
                'Deeper analytics for your teams: sector exposure, risk breakdown, and how every pick has performed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              // Feature preview cards
              FeaturePreviewCard(
                icon: Icons.pie_chart_outline,
                title: 'Sector Exposure',
                description: 'What your lineup is really betting on',
              ),
              const SizedBox(height: 12),
              FeaturePreviewCard(
                icon: Icons.shield_outlined,
                title: 'Risk Breakdown',
                description: 'Volatility by position and tier',
              ),
              const SizedBox(height: 12),
              FeaturePreviewCard(
                icon: Icons.show_chart,
                title: 'Pick Performance',
                description: 'Points contributed by every stock over time',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
