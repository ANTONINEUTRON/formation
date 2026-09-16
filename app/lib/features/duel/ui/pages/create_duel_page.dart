import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/duel/ui/cubits/duel_cubit.dart';
import 'package:symbians/features/duel/ui/widgets/duration_picker.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Challenge a player to a head-to-head duel in one sport mode.
@RoutePage()
class CreateDuelPage extends StatefulWidget {
  const CreateDuelPage({required this.mode, this.initialOpponent, super.key});

  final SportMode mode;
  final String? initialOpponent;

  @override
  State<CreateDuelPage> createState() => _CreateDuelPageState();
}

class _CreateDuelPageState extends State<CreateDuelPage> {
  late final _opponent = TextEditingController(text: widget.initialOpponent);
  late final _cubit = DuelCubit(repository: context.read<FormationRepository>(), mode: widget.mode);
  Duration _duration = duelDurations.first;
  bool _submitting = false;

  @override
  void dispose() {
    _opponent.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _submit() async {
    final opponent = _opponent.text.trim();
    if (opponent.isEmpty) {
      context.showWarningToast(message: 'Enter a username or wallet address');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _cubit.create(opponent: opponent, duration: _duration);
      if (!mounted) return;
      context.showSuccessToast(message: 'Challenge sent to $opponent');
      context.router.maybePop();
    } catch (e) {
      if (mounted) context.showErrorToast(message: errorText(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _share() {
    SharePlus.instance.share(ShareParams(
      text: 'I challenge you to a ${formatDuelDuration(_duration)} ${widget.mode.label} '
          'duel on Formation: fantasy sports with real stocks. Draft your team and accept!',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.mode.label} duel')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Opponent', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _opponent,
            autofocus: widget.initialOpponent == null,
            decoration: const InputDecoration(
              hintText: 'Username or wallet address',
              prefixIcon: Icon(Icons.person_search),
            ),
          ),
          const SizedBox(height: 24),
          Text('Duration', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DurationPicker(selected: _duration, onChanged: (d) => setState(() => _duration = d)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Both ${widget.mode.label} teams are scored from the moment your '
              'opponent accepts. Only shares held for the whole window count. '
              'No funds move: the winner gets standings credit and an on-chain trophy.',
              style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sports_mma),
            label: const Text('Send challenge'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share),
            label: const Text('Share invite link'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}
