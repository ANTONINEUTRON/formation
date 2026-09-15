import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/rounded_text_field.dart';
import 'package:symbians/features/agent/ui/widgets/agent_limit_field.dart';
import 'package:symbians/features/agent/ui/widgets/agent_section_label.dart';
import 'package:symbians/features/agent/ui/widgets/autonomy_selector.dart';
import 'package:symbians/features/agent/ui/widgets/capability_toggle.dart';
import 'package:symbians/features/agent/ui/widgets/risk_level_selector.dart';

/// Agent config page - configure an existing agent's settings.
@RoutePage()
class AgentConfigPage extends StatefulWidget {
  const AgentConfigPage({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  final String agentId;
  final String agentName;

  @override
  State<AgentConfigPage> createState() => _AgentConfigPageState();
}

class _AgentConfigPageState extends State<AgentConfigPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _strategyController;

  int _riskLevel = 2;
  AutonomyLevel _autonomy = AutonomyLevel.semiAuto;

  // Trading capabilities
  bool _spotEnabled = true;
  bool _limitEnabled = true;
  bool _perpsEnabled = false;
  bool _predictionsEnabled = false;

  // Risk limits
  final _maxPerTradeController = TextEditingController(text: '500');
  final _dailyLossLimitController = TextEditingController(text: '200');
  int _maxLeverage = 3;
  int _maxOpenPositions = 3;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.agentName);
    _strategyController = TextEditingController(
      text: 'Buy SOL whenever it drops 5% in an hour, with a 3% stop loss',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strategyController.dispose();
    _maxPerTradeController.dispose();
    _dailyLossLimitController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.router.maybePop();
    }
  }

  void _onPauseAgent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Pause Agent'),
        content: const Text(
          'Are you sure you want to pause this agent? It will stop executing trades until you resume it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Agent paused'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Pause'),
          ),
        ],
      ),
    );
  }

  void _onDeleteAgent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Agent'),
        content: const Text(
          'Are you sure you want to delete this agent? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.router.popUntilRoot();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Agent deleted'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Agent Settings'),
        actions: [
          TextButton(
            onPressed: _onSave,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Agent Name
            AgentSectionLabel('Agent Name'),
            const SizedBox(height: 8),
            RoundedFormField(
              controller: _nameController,
              hintText: 'e.g. TraderBot',
              borderRadius: 12,
              maxHeight: 56,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),

            const SizedBox(height: 24),

            // Strategy Description
            AgentSectionLabel('Strategy Description'),
            const SizedBox(height: 8),
            RoundedFormField(
              controller: _strategyController,
              hintText: 'Describe your trading strategy...',
              borderRadius: 12,
              maxLines: 4,
              maxHeight: 120,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Strategy is required' : null,
            ),

            const SizedBox(height: 24),

            // Risk Level
            AgentSectionLabel('Risk Level'),
            const SizedBox(height: 8),
            RiskLevelSelector(
              value: _riskLevel,
              onChanged: (v) => setState(() => _riskLevel = v),
            ),

            const SizedBox(height: 24),

            // Autonomy Level
            AgentSectionLabel('Autonomy Level'),
            const SizedBox(height: 8),
            AutonomySelector(
              value: _autonomy,
              onChanged: (v) => setState(() => _autonomy = v),
            ),

            const SizedBox(height: 24),

            // Risk Limits
            AgentSectionLabel('Risk Limits'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  AgentLimitField(
                    label: 'Max per trade',
                    controller: _maxPerTradeController,
                    prefix: '\$',
                  ),
                  const SizedBox(height: 16),
                  AgentLimitField(
                    label: 'Daily loss limit',
                    controller: _dailyLossLimitController,
                    prefix: '\$',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Max leverage',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                      DropdownButton<int>(
                        value: _maxLeverage,
                        dropdownColor: AppColors.surface,
                        items: [1, 2, 3, 5, 10].map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text('${v}x'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _maxLeverage = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Max open positions',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                      DropdownButton<int>(
                        value: _maxOpenPositions,
                        dropdownColor: AppColors.surface,
                        items: [1, 2, 3, 5, 10].map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text('$v'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _maxOpenPositions = v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Trading Capabilities
            AgentSectionLabel('Trading Capabilities'),
            const SizedBox(height: 8),
            CapabilityToggle(
              title: 'Spot Trading',
              subtitle: 'Execute market swaps via Jupiter',
              enabled: _spotEnabled,
              onChanged: (v) => setState(() => _spotEnabled = v),
            ),
            const SizedBox(height: 8),
            CapabilityToggle(
              title: 'Limit Orders',
              subtitle: 'Place limit orders at target prices',
              enabled: _limitEnabled,
              onChanged: (v) => setState(() => _limitEnabled = v),
            ),
            const SizedBox(height: 8),
            CapabilityToggle(
              title: 'Perpetuals',
              subtitle: 'Trade leveraged perps',
              enabled: _perpsEnabled,
              onChanged: (v) => setState(() => _perpsEnabled = v),
            ),
            const SizedBox(height: 8),
            CapabilityToggle(
              title: 'Predictions',
              subtitle: 'Participate in prediction markets',
              enabled: _predictionsEnabled,
              onChanged: (v) => setState(() => _predictionsEnabled = v),
            ),

            const SizedBox(height: 32),

            // Pause Agent
            OutlinedButton.icon(
              onPressed: _onPauseAgent,
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pause Agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 12),

            // Delete Agent
            OutlinedButton.icon(
              onPressed: _onDeleteAgent,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
