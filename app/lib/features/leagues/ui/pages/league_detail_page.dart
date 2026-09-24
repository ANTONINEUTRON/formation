import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/empty_state.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// One league: its window, its members, and the table once it is running.
@RoutePage()
class LeagueDetailPage extends StatefulWidget {
  const LeagueDetailPage({required this.leagueId, super.key});

  final String leagueId;

  @override
  State<LeagueDetailPage> createState() => _LeagueDetailPageState();
}

class _LeagueDetailPageState extends State<LeagueDetailPage> {
  late Future<League> _league;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _league = context.read<FormationRepository>().getLeague(widget.leagueId);
    });
  }

  Future<void> _settle() async {
    try {
      await context.read<FormationRepository>().settleLeague(widget.leagueId);
      _reload();
    } catch (e) {
      if (mounted) context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('League')),
      body: FutureBuilder<League>(
        future: _league,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingIndicator();
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              message: errorText(snapshot.error!),
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }

          final league = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Text(
                  league.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${league.status.label} · '
                  '${league.isDuel ? 'head to head' : '${league.memberCount} players'} · '
                  'created by ${league.createdBy}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                _CodeCard(league: league),
                const SizedBox(height: 20),
                if (league.standings.isEmpty)
                  const EmptyState(
                    icon: Icons.hourglass_empty,
                    message: 'The table appears when the league starts.',
                  )
                else
                  for (final standing in league.standings) ...[
                    _StandingRow(standing: standing),
                    const SizedBox(height: 8),
                  ],
                if (kDebugMode && league.status != LeagueStatus.fin) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _settle,
                    child: const Text('Settle now (debug)'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.league});

  final League league;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join code',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  league.joinCode,
                  style: AppTextStyles.mono(fontSize: 18, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: 'Join my ${league.mode.label} league on Formation: '
                    '${league.name} — code ${league.joinCode}',
              ),
            ),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing});

  final LeagueStanding standing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: standing.isCurrentUser ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${standing.rank}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              standing.username,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatSignedPoints(standing.points),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: pnlColor(standing.points),
            ),
          ),
        ],
      ),
    );
  }
}
