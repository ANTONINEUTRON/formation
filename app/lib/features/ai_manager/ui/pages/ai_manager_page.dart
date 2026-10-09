import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/ai_manager/ui/widgets/feature_preview_card.dart';

/// AI Manager - an assistant that advises the manager, coming soon.
///
/// Explains what it will do and how replies are paid for (credits bought with
/// SKR). The build plan lives in AI_MANAGER_PLAN.md at the repo root.
@RoutePage()
class AiManagerPage extends StatelessWidget {
  const AiManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Manager'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'COMING SOON',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Manager',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your assistant in the dugout. It studies your squad, your points and live prices, '
                    'then tells you what it would do and why.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle('What it does'),
                  const FeaturePreviewCard(
                    icon: Icons.fact_check_outlined,
                    title: 'Squad Review',
                    description: 'One tap: tier balance, weak slots and a captain pick',
                  ),
                  const SizedBox(height: 12),
                  const FeaturePreviewCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'Ask Anything',
                    description: 'Chat about your lineup, your points and the stocks you hold',
                  ),
                  const SizedBox(height: 12),
                  const FeaturePreviewCard(
                    icon: Icons.swap_horiz,
                    title: 'Suggested Moves',
                    description: 'Swaps and captain changes you apply yourself. It never trades for you',
                  ),
                  const SizedBox(height: 12),
                  const FeaturePreviewCard(
                    icon: Icons.menu_book_outlined,
                    title: 'Rules Explained',
                    description: 'Scoring, alpha against SPYx, substitutions and risk tiers',
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle('How it works'),
                  const _Step(
                    number: 1,
                    text: 'It reads your lineup, recent points and live stock prices.',
                  ),
                  const _Step(
                    number: 2,
                    text: 'It answers with a recommendation and the reasoning behind it.',
                  ),
                  const _Step(
                    number: 3,
                    text: 'You decide. Nothing changes in your squad or wallet unless you tap it.',
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Credits'),
                  const FeaturePreviewCard(
                    icon: Icons.toll_outlined,
                    title: '1 credit per reply',
                    description: 'Buy credit packs with SKR from your connected wallet',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Advice only. Match scores always come from the deterministic match engine, '
                    'never from the AI.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  const FilledButton(
                    onPressed: null,
                    child: Text('Coming soon'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
