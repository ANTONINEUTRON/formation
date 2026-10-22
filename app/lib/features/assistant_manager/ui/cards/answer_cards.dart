import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_cards.dart';
import 'package:formation/features/assistant_manager/ui/cards/card_frame.dart';
import 'package:formation/features/assistant_manager/ui/cards/line_chart.dart';
import 'package:formation/features/assistant_manager/ui/cards/sandboxed_html.dart';

/// Draws whichever card a reply carried.
class AssistantCardView extends StatelessWidget {
  const AssistantCardView({required this.card, super.key});

  final AssistantCard card;

  @override
  Widget build(BuildContext context) => switch (card) {
    final StatBoardCard c => StatBoardView(card: c),
    final CompareCard c => CompareView(card: c),
    final SquadBubblesCard c => SquadBubblesView(card: c),
    final PointsBreakdownCard c => PointsBreakdownView(card: c),
    final HtmlCard c => CardFrame(
      title: c.title,
      icon: Icons.auto_awesome_mosaic_outlined,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SandboxedHtml(html: c.html, height: c.height),
      ),
    ),
  };
}

String _usd(double v) => '\$${v.toStringAsFixed(v >= 100 ? 2 : (v >= 1 ? 2 : 4))}';
Color _tone(double? v) => v == null ? AppColors.textMuted : (v >= 0 ? AppColors.success : AppColors.error);

// ── Stat board ────────────────────────────────────────────────────────────────

class StatBoardView extends StatelessWidget {
  const StatBoardView({required this.card, super.key});

  final StatBoardCard card;

  @override
  Widget build(BuildContext context) {
    return CardFrame(
      title: 'Scouting report',
      icon: Icons.query_stats,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Logo(url: card.logoUrl, symbol: card.symbol),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          card.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TierTag(color: card.tier.color, label: card.tier.label),
                      ],
                    ),
                    Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _usd(card.priceUsd),
                    style: AppTextStyles.mono(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${formatPctChange(card.change24hPct)} 24h',
                    style: AppTextStyles.mono(fontSize: 11, color: _tone(card.change24hPct)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(label: '7D return', value: card.return7dPct, pct: true),
              _Stat(label: 'S&P 500 7D', value: card.benchmark7dPct, pct: true),
              _Stat(label: 'Alpha 7D', value: card.alpha7dPct, pct: true, highlight: true),
              if (card.position != null) _StatText(label: 'Plays', value: card.position!),
              if (card.valueUsd != null) _StatText(label: 'You hold', value: _usd(card.valueUsd!)),
            ],
          ),
          const SizedBox(height: 14),
          RangedChart(chart: card.chart),
          if (card.newsSummary != null) ...[
            const SizedBox(height: 14),
            _News(summary: card.newsSummary!, sources: card.newsSources),
          ],
        ],
      ),
    );
  }
}

class _News extends StatelessWidget {
  const _News({required this.summary, required this.sources});

  final String summary;
  final List<NewsSource> sources;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.newspaper_outlined, size: 14, color: AppColors.info),
              const SizedBox(width: 6),
              Text(
                'LATEST',
                style: AppTextStyles.mono(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary)),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in sources)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.open_in_new, size: 12),
                    label: Text(s.title, overflow: TextOverflow.ellipsis),
                    labelStyle: const TextStyle(fontSize: 11),
                    onPressed: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Compare ───────────────────────────────────────────────────────────────────

class CompareView extends StatelessWidget {
  const CompareView({required this.card, super.key});

  final CompareCard card;

  @override
  Widget build(BuildContext context) {
    final best = card.items
        .where((i) => i.return7dPct != null)
        .fold<CompareItem?>(null, (b, i) => b == null || i.return7dPct! > b.return7dPct! ? i : b);
    return CardFrame(
      title: 'Head to head',
      icon: Icons.compare_arrows,
      child: Column(
        children: [
          for (final item in card.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 4, height: 28, color: item.tier.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.symbol,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            if (item == best) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                            ],
                          ],
                        ),
                        Text(
                          item.tier.label,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _usd(item.priceUsd),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.mono(fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      item.return7dPct == null ? '—' : formatPctChange(item.return7dPct!),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.mono(
                        fontSize: 12,
                        color: _tone(item.return7dPct),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          RangedChart(chart: card.chart),
        ],
      ),
    );
  }
}

// ── Squad bubbles ─────────────────────────────────────────────────────────────

/// The lineup as bubbles: size is what each pick is worth, colour is how far
/// it is beating (lime) or trailing (red) the market today.
class SquadBubblesView extends StatefulWidget {
  const SquadBubblesView({required this.card, super.key});

  final SquadBubblesCard card;

  @override
  State<SquadBubblesView> createState() => _SquadBubblesViewState();
}

class _SquadBubblesViewState extends State<SquadBubblesView> {
  SquadBubble? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return CardFrame(
      title: 'Your squad today',
      icon: Icons.bubble_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final layout = _pack(widget.card.bubbles, Size(box.maxWidth, 200));
              return SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    for (final (bubble, center, radius) in layout)
                      Positioned(
                        left: center.dx - radius,
                        top: center.dy - radius,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = bubble == _selected ? null : bubble),
                          child: _Bubble(bubble: bubble, radius: radius, selected: bubble == selected),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? 'Size = value held · colour = beating the market today. Tap a bubble.'
                : '${selected.symbol} at ${selected.position} · ${_usd(selected.valueUsd)} held · '
                      '${selected.alphaPct == null ? 'not scored yet' : '${formatPctChange(selected.alphaPct!)} vs market'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Greedy circle packing: biggest first, each placed on a spiral at the first
  /// spot that doesn't overlap. Deterministic, so the map never jumps around.
  static List<(SquadBubble, Offset, double)> _pack(List<SquadBubble> bubbles, Size size) {
    if (bubbles.isEmpty) return const [];
    // A full football XI won't fit at the size five basketball picks do, so
    // shrink every bubble together until the whole squad fits.
    var scale = math.sqrt(5 / math.max(5, bubbles.length));
    for (var attempt = 0; attempt < 10; attempt++) {
      final layout = _tryPack(bubbles, size, scale);
      if (layout != null) return layout;
      scale *= 0.85;
    }
    return _tryPack(bubbles, size, scale, force: true)!;
  }

  static List<(SquadBubble, Offset, double)>? _tryPack(
    List<SquadBubble> bubbles,
    Size size,
    double scale, {
    bool force = false,
  }) {
    final sorted = [...bubbles]..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
    final maxValue = math.max(sorted.first.valueUsd, 0.01);
    final maxR = math.min(size.height, size.width) * 0.3 * scale;
    final minR = math.max(12.0, 18 * scale);
    final placed = <(SquadBubble, Offset, double)>[];
    final centre = Offset(size.width / 2, size.height / 2);

    for (final b in sorted) {
      final r = math.max(minR, maxR * math.sqrt(math.max(b.valueUsd, 0) / maxValue));
      Offset? spot;
      for (var step = 0; step < 2000; step++) {
        final angle = step * 0.35;
        final dist = step * 0.9;
        final candidate = centre + Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.75);
        final fits =
            candidate.dx - r >= 0 &&
            candidate.dx + r <= size.width &&
            candidate.dy - r >= 0 &&
            candidate.dy + r <= size.height &&
            placed.every((p) => (p.$2 - candidate).distance >= p.$3 + r + 3);
        if (fits) {
          spot = candidate;
          break;
        }
      }
      if (spot == null && !force) return null; // didn't fit: caller shrinks and retries
      placed.add((b, spot ?? centre, r));
    }
    return placed;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.bubble, required this.radius, required this.selected});

  final SquadBubble bubble;
  final double radius;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final alpha = bubble.alphaPct;
    // Strength of colour follows the size of the move, capped at ±2%.
    final strength = alpha == null ? 0.0 : (alpha.abs() / 2).clamp(0.15, 1.0);
    final base = alpha == null ? AppColors.textMuted : (alpha >= 0 ? AppColors.primary : AppColors.error);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: base.withValues(alpha: 0.12 + 0.35 * strength),
        border: Border.all(
          color: selected ? Colors.white : base.withValues(alpha: 0.8),
          width: selected ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bubble.symbol,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              if (alpha != null)
                Text(
                  formatPctChange(alpha),
                  style: AppTextStyles.mono(fontSize: 10, color: AppColors.textPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Points breakdown ──────────────────────────────────────────────────────────

class PointsBreakdownView extends StatelessWidget {
  const PointsBreakdownView({required this.card, super.key});

  final PointsBreakdownCard card;

  @override
  Widget build(BuildContext context) {
    final bars = [...card.bars]..sort((a, b) => b.points.compareTo(a.points));
    final scale = math.max(1.0, bars.fold<double>(0, (m, b) => math.max(m, b.points.abs())));
    return CardFrame(
      title: 'Where today\'s points came from',
      icon: Icons.stacked_bar_chart,
      trailing: Text(
        '${card.total >= 0 ? '+' : ''}${card.total.toStringAsFixed(1)} pts',
        style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w700, color: _tone(card.total)),
      ),
      child: Column(
        children: [
          for (final bar in bars)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      bar.symbol,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final half = box.maxWidth / 2;
                        final w = half * (bar.points.abs() / scale);
                        return SizedBox(
                          height: 14,
                          child: Stack(
                            children: [
                              Positioned(
                                left: half,
                                top: 0,
                                bottom: 0,
                                child: Container(width: 1, color: AppColors.border),
                              ),
                              Positioned(
                                left: bar.points >= 0 ? half : half - w,
                                top: 2,
                                bottom: 2,
                                child: Container(
                                  width: w,
                                  decoration: BoxDecoration(
                                    color: _tone(bar.points),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${bar.points >= 0 ? '+' : ''}${bar.points.toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.mono(fontSize: 12, color: _tone(bar.points)),
                    ),
                  ),
                ],
              ),
            ),
          if (card.teamPoints != 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Team bonuses: ${card.teamPoints >= 0 ? '+' : ''}${card.teamPoints.toStringAsFixed(1)} pts',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.symbol});

  final String? url;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.surfaceElevated,
      child: Text(
        symbol.substring(0, 1),
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _TierTag extends StatelessWidget {
  const _TierTag({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.pct = false, this.highlight = false});

  final String label;
  final double? value;
  final bool pct;
  final bool highlight;

  @override
  Widget build(BuildContext context) => _StatBox(
    label: label,
    highlight: highlight,
    child: Text(
      value == null ? '—' : (pct ? formatPctChange(value!) : value!.toStringAsFixed(2)),
      style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600, color: _tone(value)),
    ),
  );
}

class _StatText extends StatelessWidget {
  const _StatText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _StatBox(
    label: label,
    child: Text(value, style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.child, this.highlight = false});

  final String label;
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: highlight ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}
