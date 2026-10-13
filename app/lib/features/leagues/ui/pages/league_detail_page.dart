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
                if (league.hasFixtures) ...[
                  const _Label('Table'),
                  const SizedBox(height: 8),
                  _LeagueTable(league: league),
                  const SizedBox(height: 20),
                  const _Label('Fixtures'),
                  const SizedBox(height: 8),
                  for (final week in league.fixtures.map((f) => f.week).toSet())
                    _FixtureWeek(fixtures: league.fixtures.where((f) => f.week == week).toList()),
                  const SizedBox(height: 12),
                  const _Label('Points race'),
                  const SizedBox(height: 8),
                ],
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.textMuted),
      );
}

/// The head-to-head table: played, won, drawn, lost, points and form.
class _LeagueTable extends StatelessWidget {
  const _LeagueTable({required this.league});

  final League league;

  @override
  Widget build(BuildContext context) {
    final me = league.standings.where((s) => s.isCurrentUser).firstOrNull?.userId;
    const head = TextStyle(fontSize: 11, color: AppColors.textMuted);
    Widget cell(String text, {TextStyle? style, double width = 28}) => SizedBox(
          width: width,
          child: Text(text, textAlign: TextAlign.center, style: style ?? AppTextStyles.mono(fontSize: 12)),
        );

    final rows = league.table.isNotEmpty
        ? league.table
        : [
            // Before the first full time everyone is level.
            for (final (i, s) in league.standings.indexed)
              LeagueTableRow(
                rank: i + 1,
                userId: s.userId,
                username: s.username,
                played: 0,
                won: 0,
                drawn: 0,
                lost: 0,
                pointsFor: 0,
                pointsAgainst: 0,
                tablePoints: 0,
                form: const [],
              ),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Manager', style: head)),
              cell('P', style: head),
              cell('W', style: head),
              cell('D', style: head),
              cell('L', style: head),
              cell('Pts', style: head, width: 36),
              cell('Form', style: head, width: 64),
            ],
          ),
          const Divider(height: 14),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${row.rank}. ${row.username}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: row.userId == me ? FontWeight.w700 : FontWeight.w500,
                        color: row.userId == me ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  cell('${row.played}'),
                  cell('${row.won}'),
                  cell('${row.drawn}'),
                  cell('${row.lost}'),
                  cell('${row.tablePoints}',
                      style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w800), width: 36),
                  SizedBox(
                    width: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [for (final f in row.form) _FormDot(result: f)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FormDot extends StatelessWidget {
  const _FormDot({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result) {
      'W' => AppColors.success,
      'L' => AppColors.error,
      _ => AppColors.textMuted,
    };
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// One match week's fixtures: "anna 84.2 – 61.0 ben", or the kick-off date.
class _FixtureWeek extends StatelessWidget {
  const _FixtureWeek({required this.fixtures});

  final List<Fixture> fixtures;

  @override
  Widget build(BuildContext context) {
    final first = fixtures.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${first.weekOfSeason} · ${formatShortDate(first.kickOff.toLocal())}'
            '${first.isFinal ? ' · full time' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          for (final f in fixtures)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: f.isBye
                  ? Text('${f.homeName} has a bye', style: const TextStyle(color: AppColors.textMuted))
                  : Row(
                      children: [
                        Expanded(child: Text(f.homeName, textAlign: TextAlign.right)),
                        SizedBox(
                          width: 110,
                          child: Text(
                            f.isFinal
                                ? '${formatPoints(f.homePoints ?? 0)} – ${formatPoints(f.awayPoints ?? 0)}'
                                : 'v',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(child: Text(f.awayName ?? '')),
                      ],
                    ),
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
