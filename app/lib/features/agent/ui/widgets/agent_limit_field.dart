import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/rounded_text_field.dart';

/// Labelled text field row used for risk limit inputs in the agent config page.
class AgentLimitField extends StatelessWidget {
  const AgentLimitField({
    super.key,
    required this.label,
    required this.controller,
    required this.prefix,
  });

  final String label;
  final TextEditingController controller;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        SizedBox(
          width: 120,
          child: RoundedTextField(
            controller: controller,
            hintText: prefix,
            borderRadius: 8,
            maxHeight: 40,
            backgroundColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }
}
