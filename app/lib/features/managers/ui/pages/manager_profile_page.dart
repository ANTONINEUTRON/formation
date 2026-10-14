import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/empty_state.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/core/widgets/stat_pill.dart';
import 'package:formation/features/shared/ui/widgets/lineup_view.dart';
import 'package:formation/features/managers/ui/widgets/adopt_wallet_sheet.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Another player's profile: how they're doing, what they're fielding, and
/// the two things you can do about it — follow them, or adopt their wallet.
@RoutePage()
class ManagerProfilePage extends StatefulWidget {
  const ManagerProfilePage({
    required this.userId,
    required this.mode,
    super.key,
  });

  final String userId;
  final SportMode mode;

  @override
  State<ManagerProfilePage> createState() => _ManagerProfilePageState();
}

class _ManagerProfilePageState extends State<ManagerProfilePage> {
  Manager? _manager;
  String? _error;
  bool _busy = false;

  FormationRepository get _repository => context.read<FormationRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manager = await _repository.getManager(widget.userId, widget.mode);
      if (mounted) setState(() => _manager = manager);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  Future<void> _toggleFollow() async {
    final manager = _manager;
    if (manager == null || _busy) return;
    final next = !manager.following;

    // Optimistic: a follow button that waits on a round trip feels broken.
    setState(() {
      _busy = true;
      _manager = manager.copyWith(
        following: next,
        followers: manager.followers + (next ? 1 : -1),
      );
    });
    try {
      await _repository.setFollowing(manager.userId, following: next);
    } catch (e) {
      if (mounted) {
        setState(() => _manager = manager);
        context.showErrorToast(message: errorText(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(manager?.username ?? 'Manager')),
      body: _error != null
          ? EmptyState(
              icon: Icons.cloud_off,
              message: _error!,
              actionLabel: 'Retry',
              onAction: () {
                setState(() => _error = null);
                _load();
              },
            )
          : manager == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _Header(manager: manager),
                      const SizedBox(height: 16),
                      if (!manager.isCurrentUser) _actions(manager),
                      if (manager.skill != null) ...[
                        const SizedBox(height: 16),
                        _SkillCard(skill: manager.skill!),
                      ],
                      if (manager.badges.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final badge in manager.badges)
                              Chip(
                                avatar: const Icon(Icons.emoji_events, size: 16, color: AppColors.warning),
                                label: Text(badge.label, style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (manager.lineup.isNotEmpty) ...[
                        LineupView(roster: manager.roster),
                        const SizedBox(height: 24),
                      ],
                      if (manager.seasons.isNotEmpty) ...[
                        const _SectionLabel('Past seasons'),
                        const SizedBox(height: 8),
                        for (final season in manager.seasons)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(child: Text('Season ${season.season}')),
                                Text(
                                  '#${season.rank} of ${season.players}',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  formatPoints(season.points),
                                  style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                      const _SectionLabel('Wallet'),
                      const SizedBox(height: 8),
                      if (manager.holdings.isEmpty)
                        const EmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          message: 'This wallet holds no supported stocks.',
                        )
                      else
                        for (final holding in manager.holdings)
                          _HoldingRow(holding: holding),
                    ],
                  ),
                ),
    );
  }

  Widget _actions(Manager manager) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _toggleFollow,
            icon: Icon(
              manager.following ? Icons.check : Icons.person_add_alt_1_outlined,
              size: 18,
            ),
            label: Text(manager.following ? 'Following' : 'Follow'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: manager.holdings.isEmpty
                ? null
                : () => AdoptWalletSheet.show(
                      context,
                      manager: manager,
                      repository: _repository,
                    ),
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Adopt wallet'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.manager});

  final Manager manager;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manager.username,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      shortAddress(manager.walletAddress),
                      style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                manager.rank == null ? '—' : '#${manager.rank}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatPill(label: 'Points', value: formatPoints(manager.points)),
              StatPill(label: 'Today', value: formatSignedPoints(manager.todayPoints)),
              StatPill(
                label: 'Leagues',
                value: '${manager.leaguesWon}/${manager.leaguesPlayed}',
              ),
              StatPill(label: 'Followers', value: '${manager.followers}'),
              if (manager.streak > 0)
                StatPill(label: 'Streak', value: '${manager.streak}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skill, made visible: the rating and what's behind it.
class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final alpha = skill.alphaPerWeekPct;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                skill.rating.round().toString(),
                style: AppTextStyles.mono(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Skill rating', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      skill.ranked
                          ? 'Over ${skill.weeks} weeks · steady beats lucky'
                          : 'After ${skill.weeks} of 3 weeks needed for the Skill board',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              for (final f in skill.form)
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(left: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (f) {
                      'W' => AppColors.success,
                      'L' => AppColors.error,
                      _ => AppColors.textMuted,
                    }.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(f, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alpha >= 0
                ? 'Beats the market by ${alpha.toStringAsFixed(1)}% a week on average'
                : 'Trails the market by ${(-alpha).toStringAsFixed(1)}% a week on average',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatPill(label: 'Hit rate', value: '${skill.hitRatePct}%'),
              if (skill.shrewdCaptainPct != null)
                StatPill(label: 'Shrewd captain', value: '${skill.shrewdCaptainPct}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding});

  final ManagerHolding holding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: holding.stock.tier.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              holding.stock.tier.label,
              style: TextStyle(fontSize: 9, color: holding.stock.tier.color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  holding.stock.symbol,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (holding.starting) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, size: 12, color: AppColors.warning),
                ],
              ],
            ),
          ),
          Text(
            formatUsd(holding.valueUsd),
            style: AppTextStyles.mono(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );
}
