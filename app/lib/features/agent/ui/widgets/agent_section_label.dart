import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

/// Section header label used in agent forms (create / config).
class AgentSectionLabel extends StatelessWidget {
  const AgentSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
