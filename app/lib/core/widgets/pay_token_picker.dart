import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Token picker that sits inside an amount field.
///
/// Which tokens appear is the server's decision — SKR only shows once its
/// mint is configured — so the list is passed in rather than hardcoded.
class PayTokenPicker extends StatelessWidget {
  const PayTokenPicker({
    required this.tokens,
    required this.selected,
    required this.onChanged,
  });

  final List<PayToken> tokens;
  final PayToken selected;
  final ValueChanged<PayToken>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PayToken>(
          value: selected,
          onChanged: onChanged == null ? null : (t) => onChanged!(t!),
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: AppColors.surfaceElevated,
          icon: const Icon(Icons.expand_more, size: 18),
          items: [
            for (final token in tokens)
              DropdownMenuItem(
                value: token,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(token.iconAsset, width: 18, height: 18),
                    const SizedBox(width: 6),
                    Text(
                      token.symbol,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
