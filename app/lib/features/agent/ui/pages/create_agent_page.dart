import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/rounded_text_field.dart';
import 'package:symbians/features/agent/ui/widgets/agent_section_label.dart';
import 'package:symbians/features/agent/ui/widgets/autonomy_selector.dart';
import 'package:symbians/features/agent/ui/widgets/capability_toggle.dart';
import 'package:symbians/features/agent/ui/widgets/risk_level_selector.dart';

/// Create Agent page - form to create a new native agent.
@RoutePage()
class CreateAgentPage extends StatefulWidget {
  const CreateAgentPage({super.key});

  @override
  State<CreateAgentPage> createState() => _CreateAgentPageState();
}

class _CreateAgentPageState extends State<CreateAgentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _strategyController = TextEditingController();

  int _riskLevel = 2; // 1-5 scale
  AutonomyLevel _autonomy = AutonomyLevel.semiAuto;

  // Trading capabilities
  bool _spotEnabled = true;
  bool _limitEnabled = true;
  bool _perpsEnabled = false;
  bool _predictionsEnabled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _strategyController.dispose();
    super.dispose();
  }

  void _onCreate() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: Call agent service to create agent
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agent created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.router.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Agent'),
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
              hintText:
                  'e.g. Buy SOL whenever it drops 5% in an hour, with a 3% stop loss',
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
              subtitle: 'Place limit orders that execute at target prices',
              enabled: _limitEnabled,
              onChanged: (v) => setState(() => _limitEnabled = v),
            ),
            const SizedBox(height: 8),
            CapabilityToggle(
              title: 'Perpetuals',
              subtitle: 'Trade leveraged perps on Jupiter/Drift',
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
            const SizedBox(height: 8),
            CapabilityToggle(
              title: 'Liquidity Providing',
              subtitle: 'Manage LP positions automatically',
              enabled: false,
              comingSoon: true,
              onChanged: (_) {},
            ),

            const SizedBox(height: 32),

            // Create Button
            FilledButton(
              onPressed: _onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Agent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
