import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';

/// Round trips that lose more than this get a warning before signing.
const thinMarketWarnAt = 0.02;

/// Round trips that lose more than this need a second confirmation.
const thinMarketConfirmAt = 0.15;

/// "Thin market: if you sold straight after buying, you'd get back about
/// 48 of your 100 USDC." Built from the trade's own quotes, so it holds
/// whatever the stock's displayed price says.
class ThinMarketWarning extends StatelessWidget {
  const ThinMarketWarning({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.water_drop_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Asks once more before a trade that would lose a lot on a round trip.
Future<bool> confirmThinMarket(BuildContext context, {required String message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Thin market'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Trade anyway')),
      ],
    ),
  );
  return ok ?? false;
}
