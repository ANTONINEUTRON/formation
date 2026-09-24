import 'dart:async';
import 'dart:math';

import 'package:symbians/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/domain/roster_shapes.dart';

/// In-memory [FormationRepository] for building and demoing the UI offline.
///
/// It imitates the backend closely enough to exercise every screen: gameweeks
/// open and close, picks score points with role events, and duels settle.
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
  final Map<SportMode, Gameweek> _gameweeks = {};
  final Map<SportMode, Map<String, double>> _windowStartPrices = {};
  final Map<SportMode, List<LeaderboardEntry>> _seedBoards = {};
  final List<Duel> _duels = [];
  final List<Trophy> _trophies = [];
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
      final names = List.of(seedUsernames)..shuffle(_rng);
      _seedBoards[mode] = [
        for (var i = 0; i < 30; i++)
          LeaderboardEntry(
            rank: 0,
            userId: 'seed-${mode.apiValue}-$i',
            username: names[i],
            walletAddress: _fakeAddress(),
            points: (600 - i * 19 + _rng.nextInt(15)).toDouble(),
            gameweekPoints: (_rng.nextInt(70) - 25).toDouble(),
            streak: _rng.nextInt(6),
          ),
      ];
    }

    // Football arrives pre-drafted so League, Team and Duels all have content;
    // Basketball and American Football start empty to demo the draft.
    final picks = [
      'AAPLx', 'KOx', 'PGx', 'JNJx', 'WMTx',
      'JPMx', 'Vx', 'ORCLx', 'MAx',
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
    _openGameweek(SportMode.football, number: 13);

    final board = _seedBoards[SportMode.football]!;
    final now = DateTime.now();
    _duels.addAll([
      Duel(
        id: 'duel-1',
        challenger: _me(SportMode.football),
        opponent: board[4],
        mode: SportMode.football,
        duration: const Duration(hours: 1),
        status: DuelStatus.active,
        startTime: now.subtract(const Duration(minutes: 22)),
        endTime: now.add(const Duration(minutes: 38)),
        challengerPoints: 34,
        opponentPoints: 21,
      ),
      Duel(
        id: 'duel-2',
        challenger: board[1],
        opponent: _me(SportMode.football),
        mode: SportMode.football,
        duration: const Duration(hours: 24),
        status: DuelStatus.pending,
      ),
      Duel(
        id: 'duel-3',
        challenger: _me(SportMode.football),
        opponent: board[9],
        mode: SportMode.football,
        duration: const Duration(hours: 6),
        status: DuelStatus.settled,
        startTime: now.subtract(const Duration(days: 1, hours: 6)),
        endTime: now.subtract(const Duration(days: 1)),
        challengerPoints: 124,
        opponentPoints: -31,
        winnerId: 'me',
      ),
      Duel(
        id: 'duel-4',
        challenger: board[2],
        opponent: _me(SportMode.football),
        mode: SportMode.football,
        duration: const Duration(days: 3),
        status: DuelStatus.settled,
        startTime: now.subtract(const Duration(days: 5)),
        endTime: now.subtract(const Duration(days: 2)),
        challengerPoints: 210,
        opponentPoints: 87,
        winnerId: board[2].userId,
      ),
    ]);

    _trophies.add(Trophy(
      id: 'trophy-1',
      title: 'Duel win vs ${board[9].username}',
      mode: SportMode.football,
      awardedAt: now.subtract(const Duration(days: 1)),
    ));
  }

  XStock _bySymbol(String symbol) => _stocks.firstWhere((s) => s.symbol == symbol);

  XStock _byMint(String mint) => _stocks.firstWhere((s) => s.mint == mint);

  LeaderboardEntry _me(SportMode mode) => LeaderboardEntry(
        rank: 0,
        userId: currentUserId,
        username: _myUsername,
        walletAddress: _walletAddress,
        points: _totalPoints(mode),
        gameweekPoints: _gameweeks[mode]?.points ?? 0,
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

  // ── Gameweeks and scoring (a simplified mirror of the backend) ─────────────

  double _totalPoints(SportMode mode) =>
      (_classicPoints[mode] ?? 0) + (_gameweeks[mode]?.points ?? 0);

  void _openGameweek(SportMode mode, {int? number}) {
    final roster = _rosters[mode]!;
    final now = DateTime.now();
    _windowStartPrices[mode] = {for (final s in _stocks) s.mint: s.priceUsd};
    _gameweeks[mode] = Gameweek(
      id: 'gw-${mode.apiValue}-${_nextId++}',
      number: number ?? ((_gameweeks[mode]?.number ?? 0) + 1),
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      status: 'live',
      entered: roster.isComplete,
      points: 0,
      slots: const [],
      teamEvents: const [],
    );
  }

  /// Scores the live gameweek: alpha against SPYx, plus a few role events.
  void _rescore(SportMode mode) {
    final gameweek = _gameweeks[mode];
    final roster = _rosters[mode]!;
    if (gameweek == null || !roster.isComplete) return;

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

    _gameweeks[mode] = Gameweek(
      id: gameweek.id,
      number: gameweek.number,
      startsAt: gameweek.startsAt,
      endsAt: gameweek.endsAt,
      status: gameweek.status,
      entered: true,
      points: _round1(slots.fold<double>(0, (sum, s) => sum + s.total)),
      slots: slots,
      teamEvents: const [],
    );
  }

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
      gameweek: _gameweeks[mode],
    );
  }

  @override
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock) => _delay(() {
        final roster = _rosters[mode]!;
        final slot = roster.slots[slotIndex];
        final balance = _held[stock.mint] ?? 0;
        if (!slot.position.accepts(stock)) {
          throw StateError(
            "${stock.symbol} can't play ${slot.position.label}: it needs a "
            '${slot.position.requiredTier?.label.toLowerCase()} stock',
          );
        }
        if (balance <= 0) throw StateError('You do not hold ${stock.symbol}');
        if (roster.slots.any((s) => s.stock?.mint == stock.mint)) {
          throw StateError('${stock.symbol} is already on this team');
        }
        final slots = List.of(roster.slots)..[slotIndex] = slot.fill(stock, balance);
        _rosters[mode] = roster.copyWith(slots: slots);
        if (_rosters[mode]!.isComplete && _gameweeks[mode] == null) {
          _openGameweek(mode);
        }
        _rescore(mode);
        _notify();
        return _withStanding(mode);
      });

  @override
  Future<FormationChange> setFormation(SportMode mode, String formation) => _delay(() {
        if (mode != SportMode.football) {
          throw StateError('Only football teams have formations');
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
          throw StateError("American football teams don't have a captain");
        }
        final roster = _rosters[mode]!;
        for (final slot in [captainSlot, viceCaptainSlot]) {
          if (slot != null && !roster.slots[slot].isFilled) {
            throw StateError('Pick a stock for that slot before giving it the armband');
          }
        }
        if (captainSlot != null && captainSlot == viceCaptainSlot) {
          throw StateError('The vice-captain must be a different player');
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
  Future<List<LeaderboardEntry>> getLeaderboard(SportMode mode) => _delay(() => _board(mode));

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
          gameweekPoints: entries[i].gameweekPoints,
          streak: entries[i].streak,
          isCurrentUser: entries[i].isCurrentUser,
        ),
    ];
  }

  // ── Swaps ──────────────────────────────────────────────────────────────────

  @override
  Future<SwapQuote> getSwapQuote(XStock stock, double usdcAmount) => _delay(() {
        final fee = usdcAmount * _platformFeeBps / 10000;
        return SwapQuote(
          stock: stock,
          inputUsdc: usdcAmount,
          estimatedShares: (usdcAmount - fee) / stock.priceUsd,
          priceImpactPct: 0.0008 + usdcAmount / 2e6,
          platformFeeBps: _platformFeeBps,
          platformFeeUsdc: fee,
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

  // ── Duels ──────────────────────────────────────────────────────────────────

  @override
  Future<List<Duel>> getDuels(SportMode mode) => _delay(
        () => _duels.where((d) => d.mode == mode).toList().reversed.toList(),
      );

  @override
  Future<Duel> createDuel({
    required SportMode mode,
    required String opponent,
    required Duration duration,
  }) =>
      _delay(() {
        if (!_rosters[mode]!.isComplete) {
          throw StateError('Finish your ${mode.label} team before challenging someone');
        }
        final query = opponent.trim().toLowerCase();
        final rival = _seedBoards[mode]!.firstWhere(
          (e) => e.username.toLowerCase() == query || e.walletAddress.toLowerCase() == query,
          orElse: () => LeaderboardEntry(
            rank: 0,
            userId: 'invite-${_nextId++}',
            username: opponent.trim(),
            walletAddress: opponent.trim(),
            points: 0,
          ),
        );
        final duel = Duel(
          id: 'duel-${_nextId++}',
          challenger: _me(mode),
          opponent: rival,
          mode: mode,
          duration: duration,
          // Seeded rivals can't tap accept, so fixture mode starts duels at once.
          status: DuelStatus.active,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(duration),
          challengerPoints: 0,
          opponentPoints: 0,
        );
        _duels.add(duel);
        _notify();
        return duel;
      });

  @override
  Future<Duel> respondToDuel(String duelId, {required bool accept}) => _delay(() {
        final i = _duels.indexWhere((d) => d.id == duelId);
        final duel = _duels[i];
        if (accept && !_rosters[duel.mode]!.isComplete) {
          throw StateError('Finish your ${duel.mode.label} team before accepting');
        }
        final now = DateTime.now();
        _duels[i] = accept
            ? Duel(
                id: duel.id,
                challenger: duel.challenger,
                opponent: duel.opponent,
                mode: duel.mode,
                duration: duel.duration,
                status: DuelStatus.active,
                startTime: now,
                endTime: now.add(duel.duration),
                challengerPoints: 0,
                opponentPoints: 0,
              )
            : duel.copyWith(status: DuelStatus.declined);
        _notify();
        return _duels[i];
      });

  @override
  Future<List<Trophy>> getTrophies() => _delay(() => _trophies.reversed.toList());

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
        // Active duels drift with the live gameweek.
        for (var i = 0; i < _duels.length; i++) {
          final d = _duels[i];
          if (d.status != DuelStatus.active) continue;
          final mine = _gameweeks[d.mode]?.points ?? 0;
          final theirs = (_rng.nextDouble() - 0.5) * 40;
          _duels[i] = Duel(
            id: d.id,
            challenger: d.challenger,
            opponent: d.opponent,
            mode: d.mode,
            duration: d.duration,
            status: d.status,
            startTime: d.startTime,
            endTime: d.endTime,
            challengerPoints: d.challenger.isCurrentUser ? mine : theirs,
            opponentPoints: d.opponent.isCurrentUser ? mine : theirs,
          );
        }
        _notify();
      });

  @override
  Future<void> advanceGameweek(SportMode mode) => _delay(() {
        final gameweek = _gameweeks[mode];
        if (gameweek != null) {
          _classicPoints[mode] = (_classicPoints[mode] ?? 0) + gameweek.points;
        }
        _openGameweek(mode, number: (gameweek?.number ?? 0) + 1);
        _rescore(mode);
        _notify();
      });

  @override
  Future<Duel> settleDuel(String duelId) => _delay(() {
        final i = _duels.indexWhere((d) => d.id == duelId);
        final d = _duels[i];
        final c = d.challengerPoints ?? 0;
        final o = d.opponentPoints ?? 0;
        final winner = c >= o ? d.challenger : d.opponent;
        _duels[i] = Duel(
          id: d.id,
          challenger: d.challenger,
          opponent: d.opponent,
          mode: d.mode,
          duration: d.duration,
          status: DuelStatus.settled,
          startTime: d.startTime,
          endTime: DateTime.now(),
          challengerPoints: c,
          opponentPoints: o,
          categories: d.mode == SportMode.basketball ? _fixtureCategories(c, o) : null,
          winnerId: winner.userId,
        );
        if (winner.isCurrentUser) {
          _trophies.add(Trophy(
            id: 'trophy-${_nextId++}',
            title: 'Duel win vs ${d.rival.username}',
            mode: d.mode,
            awardedAt: DateTime.now(),
          ));
        }
        _notify();
        return _duels[i];
      });

  List<DuelCategory> _fixtureCategories(double mine, double theirs) {
    const names = {
      'alpha': 'Alpha',
      'hitRate': 'Hit rate',
      'bestPick': 'Best pick',
      'defense': 'Defense',
      'hotHand': 'Hot hand',
    };
    final lead = mine >= theirs;
    return [
      for (final entry in names.entries)
        DuelCategory(
          code: entry.key,
          name: entry.value,
          challenger: _round1(mine / 100 + _rng.nextDouble() * 0.02),
          opponent: _round1(theirs / 100 + _rng.nextDouble() * 0.02),
          winner: lead == (entry.key != 'defense') ? 'challenger' : 'opponent',
        ),
    ];
  }
}
