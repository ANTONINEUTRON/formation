import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:symbians/core/extensions/context_extensions.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/rounded_text_field.dart';
import 'package:symbians/features/strategy/ui/widgets/strategy_card.dart';

/// Strategy Marketplace - browse and adopt community trading strategies.
@RoutePage()
class StrategyMarketplacePage extends StatelessWidget {
  const StrategyMarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Strategies'),
      ),
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 85),
        child: FloatingActionButton(
          onPressed: () => context.showInfoToast(message: 'Add Strategy coming soon!'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          child: const Icon(Icons.add),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16,16,16,80),
        children: [
          // Search field
          RoundedTextField(
            hintText: 'Search strategies...',
            borderRadius: 12,
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(height: 24),

          // Strategies list
          StrategyCard(
            title: 'Momentum Trading Bot',
            creator: 'Alex Trader',
            creatorHandle: '@alextrader',
            price: '\$29.99',
            adoptions: 342,
            description: 'Trend-following strategy using RSI and MACD indicators',
            profitability: '+24% (30 days)',
            winRate: '62%',
            tags: ['RSI', 'MACD', 'Momentum'],
          ),
          const SizedBox(height: 12),

          StrategyCard(
            title: 'DCA Scaling Strategy',
            creator: 'Sam Crypto',
            creatorHandle: '@samcrypto',
            price: '\$19.99',
            adoptions: 587,
            description: 'Dollar-cost averaging with scaling based on volatility',
            profitability: '+18% (30 days)',
            winRate: '71%',
            tags: ['DCA', 'Volatility', 'Scaling'],
          ),
          const SizedBox(height: 12),

          StrategyCard(
            title: 'AI-Powered Grid Trading',
            creator: 'ML Traders Inc',
            creatorHandle: '@mltraders',
            price: '\$49.99',
            adoptions: 128,
            description: 'Neural network-based grid trading with dynamic spacing',
            profitability: '+31% (30 days)',
            winRate: '58%',
            tags: ['AI', 'Grid', 'ML'],
          ),
          const SizedBox(height: 12),

          StrategyCard(
            title: 'Arbitrage Hunter',
            creator: 'Flash Dev',
            creatorHandle: '@flashdev',
            price: '\$39.99',
            adoptions: 215,
            description: 'Cross-exchange arbitrage detection and execution',
            profitability: '+45% (30 days)',
            winRate: '81%',
            tags: ['Arbitrage', 'Multi-Exchange'],
          ),
        ],
      ),
    );
  }
}
