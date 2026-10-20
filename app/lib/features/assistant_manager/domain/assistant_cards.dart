import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/models.dart';

/// Chart ranges the backend fills, in display order.
const chartRanges = ['1D', '7D', '30D'];

/// Label the backend gives the benchmark's line.
const benchmarkLabel = 'S&P 500';

/// One line: % change from the start of the range, at each time.
class ChartSeries extends Equatable {
  const ChartSeries({required this.symbol, required this.points});

  factory ChartSeries.fromJson(Map<String, dynamic> json) => ChartSeries(
    symbol: json['symbol'] as String,
    points: [
      for (final p in json['points'] as List)
        (DateTime.fromMillisecondsSinceEpoch(((p as List)[0] as num).toInt()), (p[1] as num).toDouble()),
    ],
  );

  final String symbol;
  final List<(DateTime, double)> points;

  bool get isBenchmark => symbol == benchmarkLabel;

  @override
  List<Object?> get props => [symbol, points];
}

/// Series per range ('1D', '7D', '30D').
typedef ChartData = Map<String, List<ChartSeries>>;

ChartData _chart(Object? json) => {
  for (final MapEntry(:key, :value) in (json as Map<String, dynamic>? ?? const {}).entries)
    key: [for (final s in value as List) ChartSeries.fromJson(s as Map<String, dynamic>)],
};

double? _num(Object? v) => (v as num?)?.toDouble();

class NewsSource extends Equatable {
  const NewsSource({required this.title, required this.url});

  final String title;
  final String url;

  @override
  List<Object?> get props => [url];
}

/// An interactive panel in a reply. The model picks which; every number on
/// it comes from Formation's own data.
sealed class AssistantCard extends Equatable {
  const AssistantCard();

  static AssistantCard? fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'statBoard' => StatBoardCard.fromJson(json),
    'compare' => CompareCard.fromJson(json),
    'squadBubbles' => SquadBubblesCard.fromJson(json),
    'pointsBreakdown' => PointsBreakdownCard.fromJson(json),
    'html' => HtmlCard.fromJson(json),
    _ => null,
  };
}

class StatBoardCard extends AssistantCard {
  const StatBoardCard({
    required this.symbol,
    required this.name,
    required this.tier,
    required this.logoUrl,
    required this.priceUsd,
    required this.change24hPct,
    required this.sharesHeld,
    required this.valueUsd,
    required this.position,
    required this.return7dPct,
    required this.benchmark7dPct,
    required this.alpha7dPct,
    required this.chart,
    this.newsSummary,
    this.newsSources = const [],
  });

  factory StatBoardCard.fromJson(Map<String, dynamic> json) {
    final news = json['news'] as Map<String, dynamic>?;
    return StatBoardCard(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      tier: RiskTier.fromApi(json['tier'] as String),
      logoUrl: json['logoUrl'] as String?,
      priceUsd: _num(json['priceUsd']) ?? 0,
      change24hPct: _num(json['change24hPct']) ?? 0,
      sharesHeld: _num(json['sharesHeld']),
      valueUsd: _num(json['valueUsd']),
      position: json['position'] as String?,
      return7dPct: _num(json['return7dPct']),
      benchmark7dPct: _num(json['benchmark7dPct']),
      alpha7dPct: _num(json['alpha7dPct']),
      chart: _chart(json['chart']),
      newsSummary: news?['summary'] as String?,
      newsSources: [
        for (final s in news?['sources'] as List? ?? const [])
          NewsSource(title: (s as Map)['title'] as String, url: s['url'] as String),
      ],
    );
  }

  final String symbol;
  final String name;
  final RiskTier tier;
  final String? logoUrl;
  final double priceUsd;
  final double change24hPct;
  final double? sharesHeld;
  final double? valueUsd;
  final String? position;
  final double? return7dPct;
  final double? benchmark7dPct;
  final double? alpha7dPct;

  final ChartData chart;
  final String? newsSummary;
  final List<NewsSource> newsSources;

  @override
  List<Object?> get props => [symbol, priceUsd, chart, newsSummary];
}

class CompareItem extends Equatable {
  const CompareItem({
    required this.symbol,
    required this.name,
    required this.tier,
    required this.priceUsd,
    required this.change24hPct,
    required this.return7dPct,
  });

  final String symbol;
  final String name;
  final RiskTier tier;
  final double priceUsd;
  final double change24hPct;
  final double? return7dPct;

  @override
  List<Object?> get props => [symbol, priceUsd, return7dPct];
}

class CompareCard extends AssistantCard {
  const CompareCard({required this.items, required this.chart});

  factory CompareCard.fromJson(Map<String, dynamic> json) => CompareCard(
    items: [
      for (final i in json['items'] as List)
        CompareItem(
          symbol: (i as Map)['symbol'] as String,
          name: i['name'] as String,
          tier: RiskTier.fromApi(i['tier'] as String),
          priceUsd: _num(i['priceUsd']) ?? 0,
          change24hPct: _num(i['change24hPct']) ?? 0,
          return7dPct: _num(i['return7dPct']),
        ),
    ],
    chart: _chart(json['chart']),
  );

  final List<CompareItem> items;
  final ChartData chart;

  @override
  List<Object?> get props => [items, chart];
}

class SquadBubble extends Equatable {
  const SquadBubble({
    required this.symbol,
    required this.tier,
    required this.position,
    required this.valueUsd,
    required this.alphaPct,
  });

  final String symbol;
  final RiskTier tier;
  final String position;
  final double valueUsd;
  final double? alphaPct;

  @override
  List<Object?> get props => [symbol, valueUsd, alphaPct];
}

class SquadBubblesCard extends AssistantCard {
  const SquadBubblesCard({required this.bubbles});

  factory SquadBubblesCard.fromJson(Map<String, dynamic> json) => SquadBubblesCard(
    bubbles: [
      for (final b in json['bubbles'] as List)
        SquadBubble(
          symbol: (b as Map)['symbol'] as String,
          tier: RiskTier.fromApi(b['tier'] as String),
          position: b['position'] as String,
          valueUsd: _num(b['valueUsd']) ?? 0,
          alphaPct: _num(b['alphaPct']),
        ),
    ],
  );

  final List<SquadBubble> bubbles;

  @override
  List<Object?> get props => [bubbles];
}

class PointsBar extends Equatable {
  const PointsBar({required this.symbol, required this.position, required this.points});

  final String symbol;
  final String position;
  final double points;

  @override
  List<Object?> get props => [symbol, position, points];
}

class PointsBreakdownCard extends AssistantCard {
  const PointsBreakdownCard({required this.bars, required this.teamPoints, required this.total});

  factory PointsBreakdownCard.fromJson(Map<String, dynamic> json) => PointsBreakdownCard(
    bars: [
      for (final b in json['bars'] as List)
        PointsBar(
          symbol: (b as Map)['symbol'] as String,
          position: b['position'] as String,
          points: _num(b['points']) ?? 0,
        ),
    ],
    teamPoints: _num(json['teamPoints']) ?? 0,
    total: _num(json['total']) ?? 0,
  );

  final List<PointsBar> bars;
  final double teamPoints;
  final double total;

  @override
  List<Object?> get props => [bars, teamPoints, total];
}

/// A small page the model wrote when no native card fits. Sanitised on the
/// server (no network, strict CSP) and shown in a sandbox, display only.
class HtmlCard extends AssistantCard {
  const HtmlCard({required this.title, required this.html, required this.height});

  factory HtmlCard.fromJson(Map<String, dynamic> json) => HtmlCard(
    title: json['title'] as String? ?? 'Custom view',
    html: json['html'] as String,
    height: (json['height'] as num?)?.toDouble() ?? 320,
  );

  final String title;
  final String html;
  final double height;

  @override
  List<Object?> get props => [title, html, height];
}
