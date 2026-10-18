import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/lineup.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';

/// In-memory [FormationRepository] for building and demoing the UI offline.
///
/// It imitates the backend closely enough to exercise every screen: points
/// bank on each tick, picks score role events, and leagues settle.
/// The real scoring engine lives in the backend (docs/formation-scoring.md).
class FixtureRepository implements FormationRepository {
  FixtureRepository({required String walletAddress, int seed = 7})
      : _walletAddress = walletAddress,
        _rng = Random(seed) {
    _seed();
  }

  static const _latency = Duration(milliseconds: 350);
  static const _platformFeeBps = 30;
  static const _benchmarkSymbol = 'SPYx';

  final String _walletAddress;
  final Random _rng;
  final _changes = StreamController<void>.broadcast();

  late List<XStock> _stocks;
  final Map<String, double> _held = Map.of(heldBalanceFixtures);
  final Map<SportMode, Roster> _rosters = {};
  final Map<SportMode, double> _classicPoints = {};
  final Map<SportMode, Session> _sessions = {};
  final Map<SportMode, Map<String, double>> _windowStartPrices = {};
  final Map<SportMode, List<LeaderboardEntry>> _seedBoards = {};
  final List<League> _leagues = [];
  final List<AppNotification> _notifications = [];
  int _nextId = 100;

  @override
  String get currentUserId => 'me';

  @override
  Stream<void> get changes => _changes.stream;

  String get _myUsername => _walletAddress.length > 8
      ? '${_walletAddress.substring(0, 4)}…${_walletAddress.substring(_walletAddress.length - 4)}'
      : 'you';

  // ── Seed ────────────────────────────────────────────────────────────────────

  void _seed() {
    _stocks = List.of(xStockFixtures);

    for (final mode in SportMode.values) {
      _rosters[mode] = emptyRoster(mode);
      _classicPoints[mode] = 0;
      // Demo players go by their wallet, like a player who hasn't picked a name.
      final wallets = [for (var i = 0; i < 30; i++) _fakeAddress()];
      _seedBoards[mode] = [
        for (var i = 0; i < 30; i++)
          LeaderboardEntry(
            rank: 0,
            userId: 'seed-${mode.apiValue}-$i',
            username: '${wallets[i].substring(0, 4)}_${wallets[i].substring(wallets[i].length - 4)}',
            walletAddress: wallets[i],
            points: (600 - i * 19 + _rng.nextInt(15)).toDouble(),
            todayPoints: (_rng.nextInt(70) - 25).toDouble(),
            streak: _rng.nextInt(6),
          ),
      ];
    }

    // Football arrives pre-drafted so League and Team have content;
    // Basketball and American Football start empty to demo the draft.
    final picks = [
      'UNHx', 'KOx', 'PGx', 'JNJx', 'WMTx',
      'AAPLx', 'JPMx', 'Vx', 'MAx',
      'TSLAx', 'HOODx',
    ];
    final football = emptyRoster(SportMode.football);
    _rosters[SportMode.football] = football.copyWith(
      slots: [
        for (var i = 0; i < picks.length; i++)
          football.slots[i].fill(_bySymbol(picks[i]), _held[_bySymbol(picks[i]).mint]!),
      ],
      captainSlot: 9,
      viceCaptainSlot: 0,
    );
    _classicPoints[SportMode.football] = 312;
    _openSession(SportMode.football);

    final board = _seedBoards[SportMode.football]!;
    final now = DateTime.now();
    _leagues.addAll([
      League(
        id: 'league-1',
        name: 'Office Rivals',
        mode: SportMode.football,
        visibility: 'private',
        joinCode: 'A1B2C3D4',
        startsAt: now.subtract(const Duration(minutes: 22)),
        endsAt: now.add(const Duration(minutes: 38)),
        status: LeagueStatus.live,
        maxMembers: null,
        memberCount: 4,
        createdBy: _myUsername,
        joined: true,
        joinable: false,
        standings: [
          LeagueStanding(
            rank: 1,
            userId: currentUserId,
            username: _myUsername,
            walletAddress: _walletAddress,
            points: 34,
            isCurrentUser: true,
          ),
          for (var i = 0; i < 3; i++)
            LeagueStanding(
              rank: i + 2,
              userId: board[i].userId,
              username: board[i].username,
              walletAddress: board[i].walletAddress,
              points: 28 - i * 9,
              isCurrentUser: false,
            ),
        ],
      ),
      League(
        id: 'league-2',
        name: 'Weekend Open',
        mode: SportMode.football,
        visibility: 'public',
        joinCode: 'E5F6G7H8',
        startsAt: now.add(const Duration(hours: 3)),
        endsAt: now.add(const Duration(days: 1, hours: 3)),
        status: LeagueStatus.scheduled,
        maxMembers: null,
        memberCount: 12,
        createdBy: board[1].username,
        joined: false,
        joinable: true,
      ),
    ]);

    _notifications.addAll([
      AppNotification(
        id: 'n1',
        kind: NotificationKind.leagueJoined,
        title: '${board[3].username} joined Office Rivals',
        body: 'Your league has a new member.',
        createdAt: now.subtract(const Duration(minutes: 12)),
        data: const {'leagueId': 'league-1'},
      ),
      AppNotification(
        id: 'n2',
        kind: NotificationKind.points,
        title: "Yesterday's points are in",
        body: 'Your football team scored +41 from role events.',
        createdAt: now.subtract(const Duration(hours: 9)),
      ),
      AppNotification(
        id: 'n3',
        kind: NotificationKind.leagueSettled,
        title: 'Weekend Open is done',
        body: 'You finished #2 of 12 with 87 points.',
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
    ]);
  }

  XStock _bySymbol(String symbol) => _stocks.firstWhere((s) => s.symbol == symbol);

  XStock _byMint(String mint) => _stocks.firstWhere((s) => s.mint == mint);

  LeaderboardEntry _me(SportMode mode) => LeaderboardEntry(
        rank: 0,
        userId: currentUserId,
        username: _myUsername,
        walletAddress: _walletAddress,
        points: _totalPoints(mode),
        todayPoints: _sessions[mode]?.points ?? 0,
        isCurrentUser: true,
      );

  String _fakeAddress() {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    return List.generate(44, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
  }

  Future<T> _delay<T>(T Function() body) async {
    await Future<void>.delayed(_latency);
    return body();
  }

  void _notify() => _changes.add(null);

  // ── Sessions and scoring (a simplified mirror of the backend) ─────────────

  double _totalPoints(SportMode mode) =>
      (_classicPoints[mode] ?? 0) + (_sessions[mode]?.points ?? 0);

  void _openSession(SportMode mode) {
    final roster = _rosters[mode]!;
    final now = DateTime.now();
    _windowStartPrices[mode] = {for (final s in _stocks) s.mint: s.priceUsd};
    _sessions[mode] = Session(
      startsAt: now,
      endsAt: now.add(const Duration(days: 1)),
      entered: roster.holdsAny,
      points: 0,
      slots: const [],
      teamEvents: const [],
      substitutionsUsed: 0,
      freeSubstitutionsLeft: 3,
      matchWeek: _matchWeek(now),
      transferWindowOpen: _inTransferWindow(now),
    );
  }

  /// A rough mirror of the backend calendar: ET taken as UTC-5 all year, which
  /// is close enough for demo data. Season 1 kicked off Monday 12 Oct 2026.
  static final _anchor = DateTime.utc(2026, 10, 12, 14, 30);

  MatchWeek _matchWeek(DateTime now, {double points = 0}) {
    final weeks = now.toUtc().difference(_anchor).inDays ~/ 7;
    final number = weeks < 0 ? 1 : weeks + 1;
    final kickOff = _anchor.add(Duration(days: 7 * (number - 1)));
    return MatchWeek(
      number: number,
      season: (number - 1) ~/ 12 + 1,
      weekOfSeason: (number - 1) % 12 + 1,
      kickOff: kickOff,
      fullTime: kickOff.add(const Duration(days: 4, hours: 6, minutes: 30)),
      nextKickOff: kickOff.add(const Duration(days: 7)),
      points: points,
    );
  }

  bool _inTransferWindow(DateTime now) {
    final week = _matchWeek(now);
    return now.isBefore(week.kickOff) || now.isAfter(week.fullTime);
  }

  /// Scores the live session: alpha against SPYx, plus a few role events.
  void _rescore(SportMode mode) {
    final session = _sessions[mode];
    final roster = _rosters[mode]!;
    if (session == null || !roster.holdsAny) return;

    final start = _windowStartPrices[mode]!;
    final benchmark = _bySymbol(_benchmarkSymbol);
    final benchmarkReturn =
        (benchmark.priceUsd - start[benchmark.mint]!) / start[benchmark.mint]!;

    final slots = <SlotScore>[];
    for (var i = 0; i < roster.slots.length; i++) {
      final slot = roster.slots[i];
      final stock = slot.stock;
      if (stock == null) continue;
      final startPrice = start[stock.mint] ?? stock.priceUsd;
      final counted = (_held[stock.mint] ?? 0) > 0;
      final ownReturn = counted ? (stock.priceUsd - startPrice) / startPrice : 0.0;
      final alpha = counted ? ownReturn - benchmarkReturn : 0.0;
      final events = counted ? _events(mode, slot.position.label, ownReturn, alpha) : <ScoreEvent>[];
      final base = _round1(alpha * 1000);
      final multiplier = roster.captainSlot == i
          ? (mode == SportMode.football ? 2.0 : 1.5)
          : 1.0;
      final eventPoints = events.fold<double>(0, (sum, e) => sum + e.points);

      slots.add(SlotScore(
        slotIndex: i,
        role: slot.position.label,
        mint: stock.mint,
        symbol: stock.symbol,
        counted: counted,
        ownReturn: ownReturn,
        alpha: alpha,
        base: counted ? base : 0,
        events: events,
        multiplier: counted ? multiplier : 1,
        total: counted ? _round1((base + eventPoints) * multiplier) : 0,
      ));
    }

    final points = _round1(slots.fold<double>(0, (sum, s) => sum + s.total));
    _sessions[mode] = Session(
      startsAt: session.startsAt,
      endsAt: session.endsAt,
      entered: true,
      // Continuous banking: today's points accumulate rather than reset.
      points: points,
      slots: slots,
      teamEvents: const [],
      substitutionsUsed: session.substitutionsUsed,
      freeSubstitutionsLeft: session.freeSubstitutionsLeft,
      matchWeek: _matchWeek(DateTime.now(), points: points),
      transferWindowOpen: session.transferWindowOpen,
      // Today's events as they happen, provisional until the day closes.
      liveEvents: [
        for (final s in slots)
          for (final e in s.events)
            LiveEvent(
              slotIndex: s.slotIndex,
              mint: s.mint,
              symbol: s.symbol,
              code: e.code,
              label: e.label,
              points: e.points,
              status: 'provisional',
              at: DateTime.now(),
            ),
      ],
    );
  }

  @override
  Future<PortfolioHealth> getPortfolioHealth(SportMode mode) => _delay(() {
        final picks = [for (final s in _rosters[mode]!.slots) if (s.stock != null) s.stock!];
        final tiers = <String, int>{};
        for (final p in picks) {
          tiers[p.tier.apiValue] = (tiers[p.tier.apiValue] ?? 0) + 1;
        }
        final slots = [...?_sessions[mode]?.slots]..sort((a, b) => b.total.compareTo(a.total));
        return PortfolioHealth(
          weekOfSeason: _matchWeek(DateTime.now()).weekOfSeason,
          season: _matchWeek(DateTime.now()).season,
          points: _sessions[mode]?.points ?? 0,
          tiers: tiers,
          // Demo split; the backend works it out from the curated sector map.
          sectors: const [
            (label: 'Technology', sharePct: 46),
            (label: 'Financials', sharePct: 22),
            (label: 'Consumer staples', sharePct: 18),
            (label: 'Health care', sharePct: 14),
          ],
          balanceSectors: 4,
          balanceNeeded: 4,
          balanceBonus: 5,
          balanceEarned: false,
          carried: slots.isEmpty || slots.first.total <= 0 ? null : (symbol: slots.first.symbol, points: slots.first.total),
          dragged: slots.isEmpty || slots.last.total >= 0 ? null : (symbol: slots.last.symbol, points: slots.last.total),
          lessons: const [
            "You span 4 sectors: that's balance, and it's worth +5 at full time.",
          ],
        );
      });

  @override
  Future<MatchWeekResult> getMatchWeekResult(SportMode mode, {int? week}) => _delay(() {
        final session = _sessions[mode];
        final now = DateTime.now();
        final matchWeek = _matchWeek(now);
        final slots = [...?session?.slots]..sort((a, b) => b.total.compareTo(a.total));
        final best = slots.firstOrNull;
        return MatchWeekResult(
          week: matchWeek,
          isFinal: _inTransferWindow(now),
          points: session?.points ?? 0,
          rank: session == null ? null : 4,
          players: 128,
          manOfTheMatch: best == null || best.total <= 0 ? null : (symbol: best.symbol, points: best.total),
          goals: [
            for (final s in slots)
              for (final e in s.events)
                if (e.points > 0 && e.code == 'goal')
                  (
                    at: now.subtract(const Duration(hours: 5)),
                    symbol: s.symbol,
                    label: e.label,
                    points: e.points,
                    provisional: true,
                  ),
          ],
          turningPoint: best == null ? null : (at: now.subtract(const Duration(hours: 9)), points: best.total),
        );
      });

  List<ScoreEvent> _events(SportMode mode, String role, double ownReturn, double alpha) {
    final events = <ScoreEvent>[];
    switch (mode) {
      case SportMode.football:
        const goalPoints = {'GK': 6, 'DEF': 6, 'MID': 5, 'FWD': 4};
        const cleanSheet = {'GK': 4, 'DEF': 4, 'MID': 1, 'FWD': 0};
        final goals = (ownReturn / 0.03).floor();
        if (goals > 0) {
          events.add(ScoreEvent(
            code: 'goal',
            label: goals == 1 ? 'Goal' : '$goals goals',
            points: (goals * (goalPoints[role] ?? 0)).toDouble(),
          ));
        }
        if (alpha >= 0.01) {
          events.add(const ScoreEvent(code: 'assist', label: 'Assist', points: 3));
        }
        if (ownReturn >= 0 && (cleanSheet[role] ?? 0) > 0) {
          events.add(ScoreEvent(
            code: 'clean_sheet',
            label: 'Clean sheet',
            points: cleanSheet[role]!.toDouble(),
          ));
        }
        final conceded = (-ownReturn / 0.02).floor();
        if (conceded > 0 && (role == 'GK' || role == 'DEF')) {
          events.add(ScoreEvent(
            code: 'conceded',
            label: conceded == 1 ? 'Conceded' : 'Conceded $conceded',
            points: -conceded.toDouble(),
          ));
        }
      case SportMode.basketball:
        if (role == 'PG' || role == 'SG') {
          final buckets = (ownReturn / 0.01).floor();
          if (buckets > 0) {
            events.add(ScoreEvent(
              code: 'bucket',
              label: buckets == 1 ? 'Bucket' : '$buckets buckets',
              points: (buckets * 2).toDouble(),
            ));
          }
        }
      case SportMode.americanFootball:
        final touchdowns = (ownReturn / 0.04).floor();
        if (touchdowns > 0 && role != 'K') {
          events.add(ScoreEvent(
            code: 'touchdown',
            label: touchdowns == 1 ? 'Touchdown' : '$touchdowns touchdowns',
            points: (touchdowns * 6).toDouble(),
          ));
        }
        final turnovers = (-ownReturn / 0.04).floor();
        if (turnovers > 0 && role != 'K') {
          events.add(ScoreEvent(
            code: 'turnover',
            label: turnovers == 1 ? 'Turnover' : '$turnovers turnovers',
            points: (turnovers * -2).toDouble(),
          ));
        }
    }
    return events;
  }

  double _round1(double value) => (value * 10).roundToDouble() / 10;

  // ── Stocks & roster ────────────────────────────────────────────────────────

  @override
  Future<List<XStock>> getXStocks() => _delay(() => List.unmodifiable(_stocks));

  @override
  Future<Map<String, double>> getHeldBalances(List<String> mints) => _delay(
        () => {for (final m in mints) if ((_held[m] ?? 0) > 0) m: _held[m]!},
      );

  @override
  Future<Roster> getRoster(SportMode mode) => _delay(() => _withStanding(mode));

  Roster _withStanding(SportMode mode) {
    final roster = _rosters[mode]!;
    // Refresh prices so slot values follow the latest tick.
    final refreshed = roster.copyWith(
      slots: [
        for (final s in roster.slots)
          s.isFilled ? s.fill(_byMint(s.stock!.mint), s.balance) : s,
      ],
    );
    _rosters[mode] = refreshed;
    if (refreshed.isEmpty) return refreshed;

    return refreshed.copyWith(
      classicPoints: _totalPoints(mode),
      classicRank: _board(mode).firstWhere((e) => e.isCurrentUser).rank,
      session: _sessions[mode],
      bench: [
        for (final entry in _held.entries)
          if (entry.value > 0 &&
              !refreshed.slots.any((s) => s.stock?.mint == entry.key))
            BenchSlot(
              stock: _byMint(entry.key),
              balance: entry.value,
              eligibleSlots: [
                for (var i = 0; i < refreshed.slots.length; i++)
                  if (refreshed.slots[i].position.accepts(_byMint(entry.key))) i,
              ],
            ),
      ],
    );
  }

  @override
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock) => _delay(() {
        final roster = _rosters[mode]!;
        final slot = roster.slots[slotIndex];
        final balance = _held[stock.mint] ?? 0;
        if (!slot.position.accepts(stock)) {
          throw ValidationException(
            message: "${stock.symbol} can't play ${slot.position.label}: it "
                'needs a ${slot.position.tierLabel.toLowerCase()} stock',
          );
        }
        if (balance <= 0) throw ValidationException(message: 'You do not hold ${stock.symbol}');
        if (roster.slots.any((s) => s.stock?.mint == stock.mint)) {
          throw ValidationException(message: '${stock.symbol} is already on this team');
        }
        final slots = List.of(roster.slots)..[slotIndex] = slot.fill(stock, balance);
        _rosters[mode] = roster.copyWith(slots: slots);
        if (_rosters[mode]!.holdsAny && _sessions[mode] == null) {
          _openSession(mode);
        }
        _rescore(mode);
        _notify();
        return _withStanding(mode);
      });

  @override
  Future<FormationChange> setFormation(SportMode mode, String formation) => _delay(() {
        if (mode != SportMode.football) {
          throw const ValidationException(message: 'Only football teams have formations');
        }
        final roster = _rosters[mode]!;
        final preview = previewFormationChange(
          from: roster.formation ?? defaultFormation,
          to: formation,
          picks: roster.picksBySlot,
        );

        final shape = rosterShape(mode, formation);
        final captainMint = roster.captainSlot == null
            ? null
            : roster.slots[roster.captainSlot!].stock?.mint;
        final viceMint = roster.viceCaptainSlot == null
            ? null
            : roster.slots[roster.viceCaptainSlot!].stock?.mint;

        int? slotOf(String? mint) {
          if (mint == null) return null;
          for (final entry in preview.kept.entries) {
            if (entry.value == mint) return entry.key;
          }
          return null;
        }

        _rosters[mode] = Roster(
          mode: mode,
          formation: formation,
          captainSlot: slotOf(captainMint),
          viceCaptainSlot: slotOf(viceMint),
          slots: [
            for (var i = 0; i < shape.length; i++)
              preview.kept.containsKey(i)
                  ? RosterSlot(
                      position: shape[i],
                      stock: _byMint(preview.kept[i]!),
                      balance: _held[preview.kept[i]!] ?? 0,
                    )
                  : RosterSlot(position: shape[i]),
          ],
        );
        _rescore(mode);
        _notify();
        return FormationChange(
          roster: _withStanding(mode),
          dropped: [for (final mint in preview.dropped) _byMint(mint)],
        );
      });

  @override
  Future<Roster> setCaptaincy(
    SportMode mode, {
    int? captainSlot,
    int? viceCaptainSlot,
  }) =>
      _delay(() {
        if (mode == SportMode.americanFootball) {
          throw const ValidationException(
            message: "American football teams don't have a captain",
          );
        }
        final roster = _rosters[mode]!;
        for (final slot in [captainSlot, viceCaptainSlot]) {
          if (slot != null && !roster.slots[slot].isFilled) {
            throw const ValidationException(message: 'Pick a stock for that slot before giving it the armband');
          }
        }
        if (captainSlot != null && captainSlot == viceCaptainSlot) {
          throw const ValidationException(message: 'The vice-captain must be a different player');
        }
        _rosters[mode] = Roster(
          mode: mode,
          slots: roster.slots,
          formation: roster.formation,
          captainSlot: captainSlot,
          viceCaptainSlot: mode == SportMode.football ? viceCaptainSlot : null,
        );
        _rescore(mode);
        _notify();
        return _withStanding(mode);
      });

  // ── League ─────────────────────────────────────────────────────────────────

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    SportMode mode, {
    LeaguePeriod period = const LeaguePeriod.season(),
  }) =>
      // Fixtures hold no history, so every period shows the same board.
      _delay(() => _board(mode));

  List<LeaderboardEntry> _board(SportMode mode) {
    final roster = _rosters[mode]!;
    final entries = [
      ..._seedBoards[mode]!,
      if (!roster.isEmpty) _me(mode),
    ]..sort((a, b) => b.points.compareTo(a.points));
    return [
      for (var i = 0; i < entries.length; i++)
        LeaderboardEntry(
          rank: i + 1,
          userId: entries[i].userId,
          username: entries[i].username,
          walletAddress: entries[i].walletAddress,
          points: entries[i].points,
          todayPoints: entries[i].todayPoints,
          streak: entries[i].streak,
          isCurrentUser: entries[i].isCurrentUser,
        ),
    ];
  }

  // ── Swaps ──────────────────────────────────────────────────────────────────

  /// Both payable tokens, so the picker can be exercised offline. SOL is not
  /// one of them: swaps need it for network fees, so it is never spendable.
  @override
  Future<List<PayToken>> getPayTokens() => _delay(() => const [
        PayToken.usdc,
        PayToken(symbol: 'SKR', mint: 'SKRfixture', decimals: 9),
      ]);

  @override
  Future<SwapQuote> getSwapQuote(
    XStock stock,
    double amount, {
    PayToken payWith = PayToken.usdc,
  }) =>
      _delay(() {
        final fee = amount * _platformFeeBps / 10000;
        // Fixtures price everything in dollars, so non-USDC tokens need a
        // notional rate to turn an amount into shares.
        final rate = switch (payWith.symbol) { 'SKR' => 0.5, _ => 1.0 };
        // A paused stock's market is thin: selling straight back loses half.
        final keep = stock.isScoring ? 0.994 : 0.52;
        return SwapQuote(
          stock: stock,
          payWith: payWith.symbol,
          inputAmount: amount,
          estimatedShares: ((amount - fee) * rate) / stock.priceUsd,
          priceImpactPct: 0.0008 + amount / 2e6,
          platformFeeBps: _platformFeeBps,
          platformFee: fee,
          sellBackAmount: amount * keep,
        );
      });

  @override
  Future<double> executeSwap(SwapQuote quote) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _held.update(quote.stock.mint, (v) => v + quote.estimatedShares,
        ifAbsent: () => quote.estimatedShares);
    _notify();
    return quote.estimatedShares;
  }

  /// A simple stand-in for the backend's lineupFromHoldings: each slot, in
  /// order, takes the most valuable held stock that fits.
  @override
  Future<Roster> fillFromHoldings(SportMode mode) => _delay(() {
        final roster = _rosters[mode]!;
        if (!roster.isEmpty) {
          throw const ValidationException(message: 'Your team already has players. Change them on the draft board.');
        }
        final held = [
          for (final e in _held.entries)
            if (e.value > 0) (stock: _byMint(e.key), balance: e.value),
        ]..sort((a, b) => (b.balance * b.stock.priceUsd).compareTo(a.balance * a.stock.priceUsd));
        final used = <String>{};
        final slots = [
          for (final slot in roster.slots)
            () {
              final pick = held.where((h) => slot.position.accepts(h.stock) && !used.contains(h.stock.mint)).firstOrNull;
              if (pick == null) return slot;
              used.add(pick.stock.mint);
              return slot.fill(pick.stock, pick.balance);
            }(),
        ];
        if (used.isEmpty) {
          throw const ValidationException(message: 'None of the stocks you hold can play yet. Buy one to start your team.');
        }
        final filled = [for (var i = 0; i < slots.length; i++) if (slots[i].isFilled) i];
        _rosters[mode] = roster.copyWith(slots: slots);
        if (mode != SportMode.americanFootball && filled.isNotEmpty) {
          _rosters[mode] = Roster(
            mode: mode,
            slots: slots,
            formation: roster.formation,
            captainSlot: filled.first,
            viceCaptainSlot: mode == SportMode.football && filled.length > 1 ? filled[1] : null,
          );
        }
        if (_sessions[mode] == null) _openSession(mode);
        _notify();
        return _withStanding(mode);
      });

  @override
  Future<SellQuote> getSellQuote(XStock stock, double shares) => _delay(() {
        final held = _held[stock.mint] ?? 0;
        if (shares <= 0 || shares > held + 1e-9) {
          throw ValidationException(message: 'You hold ${held.toStringAsFixed(4)} ${stock.symbol}');
        }
        final gross = shares * stock.priceUsd * (stock.isScoring ? 0.998 : 0.6);
        final fee = gross * _platformFeeBps / 10000;
        return SellQuote(
          stock: stock,
          shares: shares,
          estimatedUsdc: gross - fee,
          priceImpactPct: 0.0008,
          platformFeeBps: _platformFeeBps,
          platformFee: fee,
          buyBackShares: shares * (stock.isScoring ? 0.994 : 0.52),
        );
      });

  @override
  Future<double> executeSell(SellQuote quote) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _held.update(quote.stock.mint, (v) => (v - quote.shares).clamp(0, double.infinity));
    _notify();
    return quote.estimatedUsdc;
  }

  // ── Leagues ────────────────────────────────────────────────────────────────

  @override
  Future<List<League>> getLeagues(SportMode mode) =>
      _delay(() => _leagues.where((l) => l.mode == mode).toList());

  @override
  Future<League> getLeague(String id) =>
      _delay(() => _leagues.firstWhere((l) => l.id == id));

  @override
  Future<League> createLeague({
    required SportMode mode,
    required String name,
    required bool isPrivate,
    required DateTime startsAt,
    required Duration duration,
    int? maxMembers,
    String? opponent,
  }) =>
      _delay(() {
        final league = League(
          id: 'league-${_nextId++}',
          name: name,
          mode: mode,
          visibility: isPrivate ? 'private' : 'public',
          joinCode: _fakeAddress().substring(0, 8).toUpperCase(),
          startsAt: startsAt,
          endsAt: startsAt.add(duration),
          status: LeagueStatus.scheduled,
          maxMembers: maxMembers,
          memberCount: opponent == null ? 1 : 2,
          createdBy: _myUsername,
          joined: true,
          joinable: false,
        );
        _leagues.add(league);
        _notify();
        return league;
      });

  @override
  Future<League> joinLeague({String? id, String? code}) => _delay(() {
        final i = _leagues.indexWhere((l) => l.id == id || l.joinCode == code);
        if (i < 0) throw const ValidationException(message: 'No league with that code');
        final l = _leagues[i];
        final joined = League(
          id: l.id,
          name: l.name,
          mode: l.mode,
          visibility: l.visibility,
          joinCode: l.joinCode,
          startsAt: l.startsAt,
          endsAt: l.endsAt,
          status: l.status,
          maxMembers: l.maxMembers,
          memberCount: l.memberCount + 1,
          createdBy: l.createdBy,
          joined: true,
          joinable: false,
          standings: l.standings,
        );
        _leagues[i] = joined;
        _notify();
        return joined;
      });

  @override
  Future<void> leaveLeague(String id) => _delay(() {
        _leagues.removeWhere((l) => l.id == id);
        _notify();
      });

  // ── Profile ────────────────────────────────────────────────────────────────

  Profile _profile = const Profile(
    userId: 'me',
    username: 'you',
    walletAddress: '',
    followers: 0,
    following: 0,
  );

  @override
  Future<Profile> getProfile() => _delay(
        () => Profile(
          userId: currentUserId,
          username: _profile.username == 'you' ? _myUsername : _profile.username,
          bio: _profile.bio,
          email: _profile.email,
          walletAddress: _walletAddress,
          followers: _profile.followers,
          following: _following.length,
        ),
      );

  @override
  Future<Profile> updateProfile({String? username, String? bio, String? email}) => _delay(() {
        _profile = Profile(
          userId: currentUserId,
          username: username ?? _profile.username,
          bio: bio == null ? _profile.bio : (bio.isEmpty ? null : bio),
          email: email == null ? _profile.email : (email.isEmpty ? null : email),
          walletAddress: _walletAddress,
          followers: _profile.followers,
          following: _following.length,
        );
        _notify();
        return _profile;
      });

  // ── Managers ───────────────────────────────────────────────────────────────

  final Set<String> _following = {};

  @override
  Future<Manager> getManager(String userId, SportMode mode) => _delay(() {
        final entry = _board(mode).firstWhere((e) => e.userId == userId);
        final roster = _rosters[mode]!;
        return Manager(
          userId: entry.userId,
          username: entry.username,
          bio: 'Fixture manager.',
          walletAddress: entry.walletAddress,
          mode: mode,
          rank: entry.rank,
          points: entry.points,
          todayPoints: entry.todayPoints,
          streak: entry.streak,
          leaguesWon: 2,
          leaguesPlayed: 5,
          lineup: roster.slots,
          formation: roster.formation,
          captainSlot: roster.captainSlot,
          viceCaptainSlot: roster.viceCaptainSlot,
          holdings: [
            for (final slot in roster.slots)
              if (slot.stock != null)
                ManagerHolding(
                  stock: slot.stock!,
                  balance: slot.balance,
                  valueUsd: slot.valueUsd,
                  starting: true,
                ),
          ],
          followers: 12,
          following: _following.contains(userId),
          isCurrentUser: entry.isCurrentUser,
        );
      });

  @override
  Future<bool> setFollowing(String userId, {required bool following}) => _delay(() {
        following ? _following.add(userId) : _following.remove(userId);
        _notify();
        return following;
      });

  // ── Notifications ──────────────────────────────────────────────────────────

  @override
  Future<List<AppNotification>> getNotifications() =>
      _delay(() => List.unmodifiable(_notifications));

  @override
  Future<int> getUnreadNotificationCount() =>
      _delay(() => _notifications.where((n) => !n.read).length);

  @override
  Future<void> markNotificationRead(String id) => _delay(() {
        final i = _notifications.indexWhere((n) => n.id == id);
        if (i >= 0) _notifications[i] = _notifications[i].copyWith(read: true);
        _notify();
      });

  @override
  Future<void> markAllNotificationsRead() => _delay(() {
        for (var i = 0; i < _notifications.length; i++) {
          _notifications[i] = _notifications[i].copyWith(read: true);
        }
        _notify();
      });

  // Fixture mode has no FCM: settings are kept in memory so the screen works.
  PushSettings _push = const PushSettings(
    available: false,
    devices: 0,
    categories: {},
    quietEnabled: true,
    quietStart: 22 * 60,
    quietEnd: 8 * 60,
    timeZone: 'UTC',
    dailyBudget: 10,
  );

  @override
  Future<void> registerPushDevice({required String token, required String platform, String? timeZone}) =>
      _delay(() {});

  @override
  Future<void> unregisterPushDevice(String token) => _delay(() {});

  @override
  Future<PushSettings> getPushSettings() => _delay(() => _push);

  @override
  Future<PushSettings> savePushSettings({
    Map<String, bool>? categories,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
    String? timeZone,
  }) =>
      _delay(() => _push = PushSettings(
            available: _push.available,
            devices: _push.devices,
            categories: {..._push.categories, ...?categories},
            quietEnabled: quietEnabled ?? _push.quietEnabled,
            quietStart: quietStart ?? _push.quietStart,
            quietEnd: quietEnd ?? _push.quietEnd,
            timeZone: timeZone ?? _push.timeZone,
            dailyBudget: _push.dailyBudget,
          ));

  // ── Assistant Manager (canned, but reads the real fixture roster) ──────────

  String? _assistantCharacterId;
  /// The welcome credits, as on the server: two squad drafts and five replies.
  int _assistantCredits = 11;
  int _draftsMade = 0;
  static const _draftCost = 3;

  /// The demo "draws" a custom avatar by using the photo for every pose.
  Uint8List? _avatarPhoto;
  int? _avatarVersion;
  String _avatarPersonality = 'mentor';
  String? _avatarName;

  List<AssistantCharacter> get _assistantCharacters => [
        ...presetCharacters,
        if (_avatarPhoto != null)
          AssistantCharacter(
            id: AssistantCharacter.customId,
            name: _avatarName ?? 'Your Assistant Manager',
            tagline: 'Your own Assistant Manager.',
            style: presetCharacters.firstWhere((c) => c.id == _avatarPersonality).style,
          ),
      ];

  AssistantProfile get _assistantProfile => AssistantProfile(
        characterId: _assistantCharacterId,
        characters: _assistantCharacters,
        avatarVersion: _avatarVersion,
        avatarCost: _avatarPhoto == null ? 0 : 20,
        credits: _assistantCredits,
        available: true,
        packs: const [
          CreditPack(id: 'credits-50', credits: 50, usd: 1),
          CreditPack(id: 'credits-300', credits: 300, usd: 5),
          CreditPack(id: 'credits-1000', credits: 1000, usd: 15),
        ],
        canBuyCredits: true,
        squadDraftCredits: _draftCost,
      );

  @override
  Future<StarterSquad> draftStarterSquad(SportMode mode, {required double budgetUsd, String? style}) =>
      _delay(() {
        final formation = mode == SportMode.football ? (_draftsMade.isEven ? '4-4-2' : '4-3-3') : null;
        final shape = rosterShape(mode, formation);
        if (budgetUsd < shape.length) {
          throw ValidationException(message: 'A squad needs a budget of at least \$${shape.length}');
        }
        // Every draft is paid from the one credit balance, as on the server.
        if (_assistantCredits < _draftCost) {
          throw const ValidationException(message: 'A squad draft costs $_draftCost credits');
        }
        _assistantCredits -= _draftCost;
        _draftsMade++;

        // Held stocks first, then the rest; a regenerate shuffles the order.
        final pool = [..._stocks.where((s) => s.symbol != _benchmarkSymbol)];
        if (_draftsMade > 1) pool.shuffle(Random(_draftsMade));
        pool.sort((a, b) => ((_held[b.mint] ?? 0) > 0 ? 1 : 0) - ((_held[a.mint] ?? 0) > 0 ? 1 : 0));
        final used = <String>{};
        final chosen = <(int, XStock)>[];
        for (var i = 0; i < shape.length; i++) {
          final stock = pool.where((s) => !used.contains(s.mint) && shape[i].accepts(s)).firstOrNull;
          if (stock == null) continue;
          used.add(stock.mint);
          chosen.add((i, stock));
        }
        final toBuy = chosen.where((c) => (_held[c.$2.mint] ?? 0) <= 0).length;
        final each = toBuy == 0 ? 0.0 : (budgetUsd / toBuy * 100).floor() / 100;

        return StarterSquad(
          mode: mode,
          formation: formation,
          captainSlot: mode == SportMode.americanFootball ? null : chosen.first.$1,
          viceCaptainSlot: mode == SportMode.football ? chosen[1].$1 : null,
          picks: [
            for (final (i, s) in chosen)
              StarterPick(
                slotIndex: i,
                position: shape[i].label,
                mint: s.mint,
                symbol: s.symbol,
                name: s.companyName,
                tier: s.tier,
                priceUsd: s.priceUsd,
                reason: (_held[s.mint] ?? 0) > 0 ? 'You already hold it.' : 'A solid ${s.tier.label.toLowerCase()} pick.',
                needsPurchase: (_held[s.mint] ?? 0) <= 0,
                amountUsd: (_held[s.mint] ?? 0) > 0 ? 0 : each,
              ),
          ],
          text: 'Here is a balanced first squad (demo). Swap anything you like before confirming.',
          budgetUsd: budgetUsd,
          skrUsd: _fixtureSkrUsd,
          draftsLeft: _assistantCredits ~/ _draftCost,
        );
      });

  @override
  Future<int> createAvatar({
    required Uint8List photo,
    required String mimeType,
    required String personality,
    String? name,
  }) =>
      _delay(() {
        final cost = _avatarPhoto == null ? 0 : 20;
        if (_assistantCredits < cost) {
          throw ValidationException(message: 'A new avatar costs $cost credits', code: outOfCreditsCode);
        }
        _assistantCredits -= cost;
        _avatarPhoto = photo;
        _avatarPersonality = personality;
        _avatarName = (name == null || name.isEmpty) ? null : name;
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
        _assistantCharacterId = AssistantCharacter.customId;
        return _assistantCredits;
      });

  @override
  Future<Uint8List> avatarImage(AssistantPose pose) => _delay(() {
        final photo = _avatarPhoto;
        if (photo == null) throw const NotFoundException(message: 'No custom avatar yet');
        return photo;
      });

  /// SKR at a made-up $0.02, so the demo shows realistic amounts.
  static const _fixtureSkrUsd = 0.02;

  @override
  Future<CreditQuote> quoteCredits(CreditPack pack) => _delay(() => CreditQuote(
        quoteId: 'quote-${_nextId++}',
        pack: pack,
        skrAmount: pack.usd / _fixtureSkrUsd,
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      ));

  @override
  Future<int> buyCredits(CreditQuote quote) => _delay(() {
        _assistantCredits += quote.pack.credits;
        return _assistantCredits;
      });

  @override
  Future<AssistantProfile> getAssistant() => _delay(() => _assistantProfile);

  @override
  Future<AssistantProfile> setAssistantCharacter(String characterId) => _delay(() {
        if (!_assistantCharacters.any((c) => c.id == characterId)) {
          throw const ValidationException(message: 'Unknown Assistant Manager');
        }
        _assistantCharacterId = characterId;
        return _assistantProfile;
      });

  @override
  Future<AssistantReply> askAssistant(
    AssistantContext context,
    List<AssistantMessage> messages,
  ) =>
      _delay(() {
        if (_assistantCharacterId == null) {
          throw const ValidationException(message: 'Pick your Assistant Manager first');
        }
        if (_assistantCredits <= 0) {
          throw const ValidationException(
            message: 'You are out of Assistant Manager credits',
            code: outOfCreditsCode,
          );
        }
        _assistantCredits--;

        final roster = _withStanding(context.mode);
        final suggestions = <AssistantSuggestion>[];
        // An empty slot and a held stock that fits it is the obvious first
        // move; otherwise suggest captaining the first pick.
        final onTeam = {for (final s in roster.slots) ?s.stock?.mint};
        for (var i = 0; i < roster.slots.length && suggestions.isEmpty; i++) {
          final position = roster.slots[i].position;
          if (roster.slots[i].isFilled) continue;
          for (final entry in _held.entries) {
            final stock = _byMint(entry.key);
            if (entry.value <= 0 || onTeam.contains(entry.key) || !position.accepts(stock)) continue;
            suggestions.add(FillSlotSuggestion(
              slotIndex: i,
              position: position.label,
              mint: stock.mint,
              symbol: stock.symbol,
              needsPurchase: false,
              substitutionCost: 0,
              reason: 'You already hold it and it fits ${position.label}.',
            ));
            break;
          }
        }
        final firstFilled = roster.slots.indexWhere((s) => s.isFilled);
        if (suggestions.isEmpty &&
            context.mode != SportMode.americanFootball &&
            firstFilled >= 0 &&
            roster.captainSlot != firstFilled) {
          suggestions.add(CaptainSuggestion(
            slotIndex: firstFilled,
            symbol: roster.slots[firstFilled].stock!.symbol,
            position: roster.slots[firstFilled].position.label,
            vice: false,
            reason: '${roster.slots[firstFilled].stock!.symbol} is your steadiest pick.',
          ));
        }

        return AssistantReply(
          text: roster.holdsAny
              ? 'You have ${roster.filledCount} of ${roster.slots.length} slots filled and '
                  '${roster.session?.points.toStringAsFixed(1) ?? '0'} points today. '
                  "Here's what I'd do next."
              : "Your lineup is empty. Put a stock you own in any slot and you'll start "
                  'scoring on the next price update.',
          mood: suggestions.isEmpty ? AssistantMood.neutral : AssistantMood.happy,
          suggestions: suggestions,
          cards: _fixtureCards(messages.last.text, roster),
          credits: _assistantCredits,
        );
      });

  /// Cards the demo answers with, picked from the question's wording.
  List<AssistantCard> _fixtureCards(String question, Roster roster) {
    final q = question.toLowerCase();
    final named = _stocks.where((s) => q.contains(s.symbol.toLowerCase())).toList();
    ChartData chart(List<String> symbols) => {
          for (final (range, days) in [('1D', 1), ('7D', 7), ('30D', 30)])
            range: [for (final s in symbols) _fixtureSeries(s, days)],
        };

    if (named.length >= 2) {
      final picks = named.take(4).toList();
      return [
        CompareCard(
          items: [
            for (final s in picks)
              CompareItem(
                symbol: s.symbol,
                name: s.companyName,
                tier: s.tier,
                priceUsd: s.priceUsd,
                change24hPct: s.change24hPct,
                return7dPct: _fixtureSeries(s.symbol, 7).points.last.$2,
              ),
          ],
          chart: chart([...picks.map((s) => s.symbol), benchmarkLabel]),
        ),
      ];
    }
    if (named.length == 1) {
      final s = named.single;
      final ret = _fixtureSeries(s.symbol, 7).points.last.$2;
      final bench = _fixtureSeries(benchmarkLabel, 7).points.last.$2;
      final held = _held[s.mint] ?? 0;
      final slot = roster.slots.where((r) => r.stock?.mint == s.mint).firstOrNull;
      return [
        StatBoardCard(
          symbol: s.symbol,
          name: s.companyName,
          tier: s.tier,
          logoUrl: s.logoUrl,
          priceUsd: s.priceUsd,
          change24hPct: s.change24hPct,
          sharesHeld: held > 0 ? held : null,
          valueUsd: held > 0 ? held * s.priceUsd : null,
          position: slot?.position.label,
          return7dPct: ret,
          benchmark7dPct: bench,
          alpha7dPct: ret - bench,
          chart: chart([s.symbol, benchmarkLabel]),
          newsSummary: '${s.companyName} is in the news this week (demo text; the live app '
              'searches the web for this).',
          newsSources: const [NewsSource(title: 'Demo source', url: 'https://example.com')],
        ),
      ];
    }
    final session = roster.session;
    if (q.contains('point') && session != null && session.slots.isNotEmpty) {
      return [
        PointsBreakdownCard(
          bars: [for (final s in session.slots) PointsBar(symbol: s.symbol, position: s.role, points: s.total)],
          teamPoints: 0,
          total: session.points,
        ),
      ];
    }
    if ((q.contains('review') || q.contains('squad')) && roster.holdsAny) {
      final scores = {for (final s in session?.slots ?? const <SlotScore>[]) s.slotIndex: s};
      return [
        SquadBubblesCard(
          bubbles: [
            for (var i = 0; i < roster.slots.length; i++)
              if (roster.slots[i].stock case final stock?)
                SquadBubble(
                  symbol: stock.symbol,
                  tier: stock.tier,
                  position: roster.slots[i].position.label,
                  valueUsd: roster.slots[i].valueUsd,
                  alphaPct: scores[i] == null ? null : scores[i]!.alpha * 100,
                ),
          ],
        ),
      ];
    }
    return const [];
  }

  /// A deterministic made-up % path for [symbol] over [days], for demo charts.
  ChartSeries _fixtureSeries(String symbol, int days) {
    final rng = Random(symbol.hashCode ^ days);
    final now = DateTime.now();
    const steps = 48;
    var pct = 0.0;
    final points = <(DateTime, double)>[];
    for (var i = 0; i <= steps; i++) {
      if (i > 0) pct += (rng.nextDouble() - 0.47) * 0.6 * days / 7;
      points.add((now.subtract(Duration(minutes: (days * 24 * 60 * (steps - i) / steps).round())), pct));
    }
    return ChartSeries(symbol: symbol, points: points);
  }

  // ── Demo controls ──────────────────────────────────────────────────────────

  @override
  Future<void> runTick() => _delay(() {
        _stocks = [
          for (final s in _stocks)
            XStock(
              symbol: s.symbol,
              companyName: s.companyName,
              mint: s.mint,
              tier: s.tier,
              priceUsd: s.priceUsd * (1 + (_rng.nextDouble() - 0.47) * 0.03),
              change24hPct: s.change24hPct,
            ),
        ];
        for (final mode in SportMode.values) {
          _rescore(mode);
        }
        _notify();
      });

  @override
  Future<void> processLeagues() => _delay(_notify);

  @override
  Future<void> settleLeague(String id) => _delay(() {
        final i = _leagues.indexWhere((l) => l.id == id);
        if (i < 0) return;
        final l = _leagues[i];
        _leagues[i] = League(
          id: l.id,
          name: l.name,
          mode: l.mode,
          visibility: l.visibility,
          joinCode: l.joinCode,
          startsAt: l.startsAt,
          endsAt: l.endsAt,
          status: LeagueStatus.fin,
          maxMembers: l.maxMembers,
          memberCount: l.memberCount,
          createdBy: l.createdBy,
          joined: l.joined,
          joinable: false,
          standings: l.standings,
        );
        _notify();
      });
}
