import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/domain/entity/transaction.dart';
import 'package:symbians/features/profile/ui/widgets/transaction_tile.dart';

/// Transaction history page.
@RoutePage()
class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _dummyTransactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final tx = _dummyTransactions[index];
          return TransactionTile(transaction: tx);
        },
      ),
    );
  }
}

final _dummyTransactions = [
  const Transaction(
    type: 'Transfer',
    amount: '50.00',
    symbol: 'USDC',
    description: 'From 7xKX...3mNq',
    timestamp: '2 hours ago',
    isIncoming: true,
  ),
  const Transaction(
    type: 'Swap',
    amount: '0.5',
    symbol: 'SOL',
    description: 'Swapped for USDC',
    timestamp: '5 hours ago',
    isIncoming: false,
  ),
  const Transaction(
    type: 'Agent Fee',
    amount: '100',
    symbol: 'SKR',
    description: 'Explorer Bot activity',
    timestamp: '1 day ago',
    isIncoming: false,
  ),
  const Transaction(
    type: 'Reward',
    amount: '500',
    symbol: 'SKR',
    description: 'World exploration bonus',
    timestamp: '2 days ago',
    isIncoming: true,
  ),
  const Transaction(
    type: 'Transfer',
    amount: '2.0',
    symbol: 'SOL',
    description: 'To 9pQR...8kLm',
    timestamp: '3 days ago',
    isIncoming: false,
  ),
];
