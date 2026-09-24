import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/core/widgets/loading_indicator.dart';
import 'package:symbians/features/duel/ui/cubits/duel_cubit.dart';
import 'package:symbians/features/duel/ui/cubits/duel_state.dart';
import 'package:symbians/features/duel/ui/widgets/category_scoreboard.dart';
import 'package:symbians/features/duel/ui/widgets/duel_countdown.dart';
import 'package:symbians/features/duel/ui/widgets/head_to_head_bar.dart';
import 'package:symbians/features/duel/ui/widgets/trophy_award_dialog.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/models.dart';

@RoutePage()
class DuelDetailPage extends StatelessWidget {
  const DuelDetailPage({required this.duelId, required this.mode, super.key});

  final String duelId;
  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DuelCubit(repository: context.read<FormationRepository>(), mode: mode)..load(),
      child: Scaffold(
        appBar: AppBar(title: Text('${mode.label} duel')),
        body: BlocBuilder<DuelCubit, DuelState>(
          builder: (context, state) {
            final duel = state.byId(duelId);
            if (duel == null) return const LoadingIndicator();
            return _DuelDetailBody(duel: duel, isBusy: state.busyDuelId == duel.id);
          },
        ),
      ),
    );
  }
}

class _DuelDetailBody extends StatelessWidget {
  const _DuelDetailBody({required this.duel, required this.isBusy});

  final Duel duel;
  final bool isBusy;

  Future<void> _run(BuildContext context, Future<Duel> Function(DuelCubit) action) async {
    final cubit = context.read<DuelCubit>();
    try {
      final result = await action(cubit);
      if (!context.mounted) return;
      if (result.status == DuelStatus.settled) {
        if (result.iWon) {
          await TrophyAwardDialog.show(context, result);
        } else {
          context.showInfoToast(message: '${result.rival.username} won this one.');
        }
      }
    } catch (e) {
      if (context.mounted) context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showScores = duel.status == DuelStatus.active || duel.status == DuelStatus.settled;
    final categories = duel.categories;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: _Player(entry: duel.me, highlight: duel.iWon)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: _Player(
                entry: duel.rival,
                highlight: duel.status == DuelStatus.settled && !duel.iWon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (showScores)
          HeadToHeadBar(
            myPoints: duel.myPoints,
            rivalPoints: duel.rivalPoints,
            myLabel: 'You',
            rivalLabel: duel.rival.username,
            height: 16,
          ),
        if (categories != null && categories.isNotEmpty) ...[
          const SizedBox(height: 20),
          CategoryScoreboard(
            categories: categories,
            viewerIsChallenger: duel.challenger.isCurrentUser,
          ),
        ],
        const SizedBox(height: 24),
        _InfoRow(label: 'Duration', value: formatDuelDuration(duel.duration)),
        _InfoRow(label: 'Status', value: _statusText),
        _InfoRow(
          label: 'Decided on',
          value: duel.mode == SportMode.basketball ? 'Categories' : 'Points',
        ),
        if (duel.status == DuelStatus.active && duel.endTime != null)
          _InfoRow(label: 'Ends in', child: DuelCountdown(endTime: duel.endTime!)),
        if (duel.startTime != null) _InfoRow(label: 'Started', value: _time(duel.startTime!)),
        if (duel.status == DuelStatus.settled && duel.endTime != null)
          _InfoRow(label: 'Settled', value: _time(duel.endTime!)),
        if (duel.mySlots.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Your picks', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final slot in duel.mySlots)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      slot.role,
                      style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  Expanded(
                    child: Text(slot.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    formatSignedPoints(slot.total),
                    style: AppTextStyles.mono(fontSize: 13, color: pnlColor(slot.total)),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 24),
        if (duel.awaitingMyResponse)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      isBusy ? null : () => _run(context, (c) => c.respond(duel.id, accept: false)),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      isBusy ? null : () => _run(context, (c) => c.respond(duel.id, accept: true)),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        if (kDebugMode && duel.status == DuelStatus.active)
          OutlinedButton.icon(
            onPressed: isBusy ? null : () => _run(context, (c) => c.settle(duel.id)),
            icon: const Icon(Icons.flag),
            label: const Text('Settle now (debug)'),
          ),
      ],
    );
  }

  String get _statusText => switch (duel.status) {
        DuelStatus.pending =>
          duel.awaitingMyResponse ? 'Waiting for you' : 'Waiting for opponent',
        DuelStatus.active => 'Live',
        DuelStatus.declined => 'Declined',
        DuelStatus.settled => duel.winnerId == null
            ? 'Draw'
            : duel.iWon
                ? 'You won'
                : 'You lost',
      };

  String _time(DateTime t) =>
      '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _Player extends StatelessWidget {
  const _Player({required this.entry, required this.highlight});

  final LeaderboardEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: highlight ? AppColors.primary : AppColors.surfaceElevated,
          child: Text(
            entry.username.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.textInverse : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.isCurrentUser ? 'You' : entry.username,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          shortAddress(entry.walletAddress),
          style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          child ??
              Text(
                value ?? '',
                style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600),
              ),
        ],
      ),
    );
  }
}
