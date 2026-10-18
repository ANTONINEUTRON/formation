import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/legal_links.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/assistant_sheet.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';

/// The rules in one place: positions, points, limits, substitutions, match
/// weeks and fixtures. Numbers here are kept in step with the scoring engine
/// (`backend/src/scoring/engine/score-entry.ts`, `domain/sport.ts`) and the
/// Assistant Manager's rules (`backend/src/assistant/prompt.ts`) by hand.
@RoutePage()
class HowToPlayPage extends StatefulWidget {
  const HowToPlayPage({this.mode = SportMode.football, this.showAssistant = true, super.key});

  /// The sport shown first; the Manager can switch.
  final SportMode mode;

  /// Off before a wallet is connected (onboarding), when there's no
  /// Assistant Manager to ask yet.
  final bool showAssistant;

  @override
  State<HowToPlayPage> createState() => _HowToPlayPageState();
}

class _HowToPlayPageState extends State<HowToPlayPage> {
  late SportMode _mode = widget.mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('How to play')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              const _Section(
                icon: Icons.sports_soccer,
                title: 'Your stocks are your players',
                children: [
                  _Para(
                    'Your team is made of tokenized US stocks (xStocks, like AAPLx for Apple) that you '
                    'hold in your own Solana wallet. Only stocks you hold can play. Buy more in the app '
                    'whenever you like; they go straight to your wallet.',
                  ),
                ],
              ),
              _Section(
                icon: Icons.grid_view_rounded,
                title: 'Positions',
                children: [
                  const _Para('Every stock has a tier, and each position takes one tier:'),
                  const SizedBox(height: 8),
                  for (final tier in RiskTier.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          _TierTag(label: tier.label, color: tier.color),
                          const SizedBox(width: 10),
                          Expanded(child: _Para(tier.meaning)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  const _Para(
                    'Tiers come from how each stock actually behaved over the last 90 days: how much it '
                    'moves with the market (beta) and how much it swings on its own (volatility). The '
                    'calmest third are blue chips, the middle third balanced, the wildest third momentum. '
                    "They're recalculated each season, a stock moves at most one tier at a time, and a "
                    'pick already in your team keeps its place.',
                    muted: true,
                  ),
                  const SizedBox(height: 12),
                  const _Para('Pick a sport to see its positions.'),
                  const SizedBox(height: 12),
                  _SportPicker(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
                  const SizedBox(height: 12),
                  _Positions(mode: _mode),
                  if (_mode == SportMode.football) ...[
                    const SizedBox(height: 8),
                    const _Para(
                      'Pick any formation from 3-4-3 to 5-4-1: one keeper, 3–5 defenders, 2–5 '
                      'midfielders and 1–3 forwards.',
                      muted: true,
                    ),
                  ],
                ],
              ),
              const _Section(
                icon: Icons.trending_up,
                title: 'How you score',
                children: [
                  _Para(
                    'A pick earns 1 point for every 0.1% it beats the market (the S&P 500). Points '
                    'come from beating the market, not from rising with it.',
                  ),
                  SizedBox(height: 12),
                  _Example(
                    rows: [
                      ('Your pick rises 2.0%, the market 1.0%', '+10 pts'),
                      ('Both rise 2.0%', '0 pts'),
                      ('Your pick falls 1.0%, the market rises 0.5%', '−15 pts'),
                    ],
                  ),
                  SizedBox(height: 12),
                  _Para(
                    'Scoring runs all the time: a stock scores whenever its price is reliable. Points '
                    'are banked as they happen, and the day closes into your session total.',
                  ),
                ],
              ),
              _Section(
                icon: Icons.military_tech_outlined,
                title: 'Captain',
                children: [_Para(_captainText(_mode))],
              ),
              _Section(
                icon: Icons.bolt_rounded,
                title: 'Bonus events',
                children: [
                  const _Para('Positions also earn events on top of their base points, once a day:'),
                  const SizedBox(height: 8),
                  for (final line in _events(_mode)) _Bullet(line),
                ],
              ),
              const _Section(
                icon: Icons.shield_outlined,
                title: 'Limits that keep it fair',
                children: [
                  _Bullet(
                    'A single price move counts for at most 10% against the market. A bigger jump '
                    'waits to be confirmed by the next price.',
                  ),
                  _Bullet('Each pick can earn or lose at most 150 base points a day, and 60 in events.'),
                  _Bullet(
                    'A stock only scores while its market is deep: buying \$500 of it and selling '
                    'straight back must lose under 2%. A thin market is cheap to push around, so it '
                    "can't count for points.",
                  ),
                  _Bullet(
                    "A stock that fails that, or whose price is stale or erratic, isn't scoring: it shows "
                    "a small orange ⓘ. It banks nothing and can't be captain until its price has been "
                    'reliable for a full day. You can still pick it, buy it or sell it, and the app shows '
                    'what a thin market would cost you first.',
                  ),
                ],
              ),
              const _Section(
                icon: Icons.swap_horiz_rounded,
                title: 'Substitutes',
                children: [
                  _Bullet(
                    'Every stock you hold that isn\'t starting sits on your bench (4 spots in football, 3 '
                    'in basketball, 6 in American football; "More" shows the rest). Bring one on in any '
                    'spot its tier fits.',
                  ),
                  _Bullet('3 free substitutions a day; each one after that costs 4 points.'),
                  _Bullet('Filling an empty slot is always free.'),
                  _Bullet('Weekend substitutions are free: the transfer window is open.'),
                  _Bullet(
                    'Buying and selling stocks never costs points. Selling a pick in your team takes it '
                    'off at the points it has banked.',
                  ),
                ],
              ),
              const _Section(
                icon: Icons.calendar_month_outlined,
                title: 'Match weeks and seasons',
                children: [
                  _Bullet('A match week runs from Monday 9:30am ET (kick-off) to Friday 4pm ET (full time).'),
                  _Bullet('Twelve match weeks make a season. The Season board is the main table.'),
                  _Bullet(
                    'Before a season starts it\'s pre-season (friendlies in football, preseason games in '
                    "basketball and American football): points bank, but they don't count toward the season.",
                  ),
                  _Bullet(
                    'Balance bonus: +5 points at full time when your picks cover 4 or more sectors.',
                  ),
                  _Bullet(
                    'Your skill rating (0–100) rewards beating the market steadily week after week, '
                    'not one lucky week. It appears after your first full match week.',
                  ),
                ],
              ),
              const _Section(
                icon: Icons.emoji_events_outlined,
                title: 'Leagues and fixtures',
                children: [
                  _Bullet('Everyone plays in the global league automatically.'),
                  _Bullet(
                    'In a private league you face one member each match week. The higher points '
                    'total wins: 3 league points for a win, 1 for a draw (within half a point).',
                  ),
                  _Bullet('A duel is a two-player private league over a set time.'),
                  _Bullet(
                    'Winning earns standing on a leaderboard. There is no prize pool and nothing '
                    'is staked.',
                  ),
                ],
              ),
              if (widget.showAssistant) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => showAssistantSheet(
                    context,
                    AssistantContext(mode: _mode, screen: 'profile'),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Ask your Assistant Manager'),
                ),
              ],
              const SizedBox(height: 24),
              const LegalLinks(lead: 'By playing ${AppConstants.appName}, you agree to the'),
            ],
          ),
        ),
      ),
    );
  }
}

String _captainText(SportMode mode) => switch (mode) {
  SportMode.football =>
    'Your captain scores double. Name a vice-captain too: they take over if your captain '
        'isn\'t in your wallet.',
  SportMode.basketball => 'Your captain scores 1.5 times their points.',
  SportMode.americanFootball => 'American football has no captain: every pick counts the same.',
};

List<String> _events(SportMode mode) => switch (mode) {
  SportMode.football => const [
    'Goal: for every 3% a pick rises (keeper or defender 6 pts, midfielder 5, forward 4).',
    'Assist: +3 when a pick beats the market by 1% or more.',
    'Clean sheet: when a pick doesn\'t fall (keeper or defender 4 pts, midfielder 1).',
    'Keepers and defenders lose 1 point for every 2% they fall.',
  ],
  SportMode.basketball => const [
    'Bucket: point and shooting guards +2 for every 1% they rise.',
    'Block: the center +5 for each day it held up while the market fell.',
    'Double-double: +5 when 2 or more picks beat the market by 1% in a day.',
  ],
  SportMode.americanFootball => const [
    'Touchdown: +6 for every 4% a pick rises (all but the kicker).',
    'Reception: wide receivers and the tight end +0.5 for each day they rise.',
    'Turnover: −2 for every 4% a pick falls (all but the kicker).',
    'Clean pocket: the quarterback +4 if it never dropped 2%.',
    'Field goal: the kicker +1 for each day it rises.',
  ],
};

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: muted ? 12.5 : 14,
        height: 1.5,
        color: muted ? AppColors.textMuted : AppColors.textSecondary,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          Expanded(child: _Para(text)),
        ],
      ),
    );
  }
}

/// Worked examples: what happened, and the points it earns.
class _Example extends StatelessWidget {
  const _Example({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          for (final (what, points) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      what,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    points,
                    style: AppTextStyles.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: points.startsWith('+')
                          ? AppColors.success
                          : points.startsWith('−')
                          ? AppColors.error
                          : AppColors.textPrimary,
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

class _SportPicker extends StatelessWidget {
  const _SportPicker({required this.mode, required this.onChanged});

  final SportMode mode;
  final ValueChanged<SportMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in SportMode.values)
          ChoiceChip(
            avatar: Icon(m.icon, size: 16, color: m == mode ? AppColors.background : AppColors.textSecondary),
            label: Text(m.label),
            selected: m == mode,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: m == mode ? AppColors.background : AppColors.textSecondary,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary,
            side: BorderSide(color: m == mode ? AppColors.primary : AppColors.border),
            onSelected: (_) => onChanged(m),
          ),
      ],
    );
  }
}

/// One row per position: its label, how many there are, and the tiers it takes.
class _Positions extends StatelessWidget {
  const _Positions({required this.mode});

  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    // Group slots by label, keeping first-seen order and every tier the label
    // accepts across its slots (e.g. American football's RBs).
    final counts = <String, int>{};
    final tiers = <String, List<RiskTier>>{};
    for (final slot in rosterShape(mode)) {
      counts[slot.label] = (counts[slot.label] ?? 0) + 1;
      final list = tiers.putIfAbsent(slot.label, () => []);
      for (final tier in [if (slot.requiredTier != null) slot.requiredTier!, ...slot.alsoAccepts]) {
        if (!list.contains(tier)) list.add(tier);
      }
    }

    return Column(
      children: [
        for (final label in counts.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    mode == SportMode.football || counts[label] == 1 ? label : '$label ×${counts[label]}',
                    style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (tiers[label]!.isEmpty)
                        const _TierTag(label: 'Any tier', color: AppColors.textSecondary)
                      else
                        for (final tier in tiers[label]!) _TierTag(label: tier.label, color: tier.color),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TierTag extends StatelessWidget {
  const _TierTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
