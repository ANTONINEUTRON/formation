import 'dart:async';
import 'dart:math';

import 'package:symbians/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/domain/roster_shapes.dart';
import 'package:symbians/features/shared/domain/scoring.dart';

/// In-memory [FormationRepository] for building and demoing the UI offline.
///
/// State is mutable for the app's lifetime: drafts, duels and ticks all
/// persist until restart. Prices only move when [runTick] is called, and ticks
/// use the same [scoreWindow] math as the backend.
class FixtureRepository implements FormationRepository {
  FixtureRepository({required String walletAddress, int seed = 7})
      : _walletAddress = walletAddress,
        _rng = Random(seed) {
    _seed();
  }

  static const _latency = Duration(milliseconds: 350);
  static const _platformFeeBps = 30;

  final String _walletAddress;
  final Random _rng;
  final _changes = StreamController<void>.broadcast();

  late List<XStock> _stocks;
  final Map<String, double> _held = Map.of(heldBalanceFixtures);
  final Map<SportMode, Roster> _rosters = {};
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
      final names = List.of(seedUsernames)..shuffle(_rng);
      _seedBoards[mode] = [
        for (var i = 0; i < 30; i++)
          LeaderboardEntry(
            rank: 0,
            userId: 'seed-${mode.apiValue}-$i',
            username: names[i],
            walletAddress: _fakeAddress(),
            points: 600 - i * 19 + _rng.nextInt(15),
            streak: _rng.nextInt(6),
          ),
      ];
    }

    // Football arrives pre-drafted so League, Team and Duels all have content;
    // Basketball and American Football start empty to demo the draft.
    final football = emptyRoster(SportMode.football);
    // Squad order: GK×2, DEF×5, MID×5, FWD×3. Default 4-4-2, TSLAx captain.
    final picks = [
      'AAPLx', 'SPYx',
      'KOx', 'PGx', 'JNJx', 'WMTx', 'MCDx',
      'JPMx', 'Vx', 'ORCLx', 'MAx', 'UNHx',
      'TSLAx', 'HOODx', 'PLTRx',
    ];
    _rosters[SportMode.football] = football.copyWith(
      slots: [
        for (var i = 0; i < picks.length; i++)
          football.slots[i].fill(_bySymbol(picks[i]), _held[_bySymbol(picks[i]).mint]!),
      ],
      lineup: football.lineup!.withCaptain(12).withViceCaptain(0),
      classicPoints: 312,
      lastReturnPct: 0.0041,
      lastTickAt: DateTime.now().subtract(const Duration(minutes: 18)),
    );

    final board = _seedBoards[SportMode.football]!;
    final now = DateTime.now();
    _duels.addAll([
      Duel(
        id: 'duel-1',
        challenger: _me(),
        opponent: board[4],
        mode: SportMode.football,
        duration: const Duration(hours: 1),
        status: DuelStatus.active,
        startTime: now.subtract(const Duration(minutes: 22)),
        endTime: now.add(const Duration(minutes: 38)),
        challengerReturnPct: 0.0032,
        opponentReturnPct: 0.0019,
      ),
      Duel(
        id: 'duel-2',
        challenger: board[1],
        opponent: _me(),
        mode: SportMode.football,
        duration: const Duration(hours: 24),
        status: DuelStatus.pending,
      ),
      Duel(
        id: 'duel-3',
        challenger: _me(),
        opponent: board[9],
        mode: SportMode.football,
        duration: const Duration(hours: 6),
        status: DuelStatus.settled,
        startTime: now.subtract(const Duration(days: 1, hours: 6)),
        endTime: now.subtract(const Duration(days: 1)),
        challengerReturnPct: 0.0124,
        opponentReturnPct: -0.0031,
        winnerId: 'me',
      ),
      Duel(
        id: 'duel-4',
        challenger: board[2],
        opponent: _me(),
        mode: SportMode.football,
        duration: const Duration(days: 3),
        status: DuelStatus.settled,
        startTime: now.subtract(const Duration(days: 5)),
        endTime: now.subtract(const Duration(days: 2)),
        challengerReturnPct: 0.0210,
        opponentReturnPct: 0.0087,
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

  LeaderboardEntry _me() {
    final roster = _rosters.values.firstWhere((r) => !r.isEmpty, orElse: () => _rosters[SportMode.football]!);
    return LeaderboardEntry(
      rank: roster.classicRank ?? 0,
      userId: currentUserId,
      username: _myUsername,
      walletAddress: _walletAddress,
      points: roster.classicPoints,
      isCurrentUser: true,
    );
  }

  String _fakeAddress() {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    return List.generate(44, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
  }

  Future<T> _delay<T>(T Function() body) async {
    await Future<void>.delayed(_latency);
    return body();
  }

  void _notify() => _changes.add(null);

  // ── Stocks & roster ────────────────────────────────────────────────────────

  @override
  Future<List<XStock>> getXStocks() => _delay(() => List.unmodifiable(_stocks));

  @override
  Future<Map<String, double>> getHeldBalances(List<String> mints) => _delay(
        () => {for (final m in mints) if ((_held[m] ?? 0) > 0) m: _held[m]!},
      );

  @override
  Future<Roster> getRoster(SportMode mode) => _delay(() => _withRank(_rosters[mode]!));

  Roster _withRank(Roster roster) {
    if (roster.isEmpty) return roster;
    final rank = _board(roster.mode).firstWhere((e) => e.isCurrentUser).rank;
    // Refresh stock prices so slot values reflect the latest tick.
    return roster.copyWith(
      classicRank: rank,
      slots: [
        for (final s in roster.slots)
          s.isFilled ? s.fill(_stocks.firstWhere((x) => x.mint == s.stock!.mint), s.balance) : s,
      ],
    );
  }

  @override
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock) => _delay(() {
        final roster = _rosters[mode]!;
        final slot = roster.slots[slotIndex];
        final balance = _held[stock.mint] ?? 0;
        if (!slot.position.accepts(stock)) {
          throw StateError('${stock.symbol} is not eligible for ${slot.position.label}');
        }
        if (balance <= 0) throw StateError('You do not hold ${stock.symbol}');
        if (roster.slots.any((s) => s.stock?.mint == stock.mint)) {
          throw StateError('${stock.symbol} is already on this roster');
        }
        final slots = List.of(roster.slots)..[slotIndex] = slot.fill(stock, balance);
        _rosters[mode] = roster.copyWith(slots: slots);
        _notify();
        return _withRank(_rosters[mode]!);
      });

  @override
  Future<Roster> setLineup(SportMode mode, Lineup lineup) => _delay(() {
        if (mode != SportMode.football) throw StateError('Only football has lineups');
        if (!lineup.isValid) throw StateError('That lineup breaks formation rules');
        _rosters[mode] = _rosters[mode]!.copyWith(lineup: lineup);
        _notify();
        return _withRank(_rosters[mode]!);
      });

  // ── League ─────────────────────────────────────────────────────────────────

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(SportMode mode) => _delay(() => _board(mode));

  List<LeaderboardEntry> _board(SportMode mode) {
    final roster = _rosters[mode]!;
    final entries = [
      ..._seedBoards[mode]!,
      if (!roster.isEmpty)
        LeaderboardEntry(
          rank: 0,
          userId: currentUserId,
          username: _myUsername,
          walletAddress: _walletAddress,
          points: roster.classicPoints,
          streak: _duels.where((d) => d.mode == mode && d.iWon).length,
          isCurrentUser: true,
        ),
    ]..sort((a, b) => b.points.compareTo(a.points));
    return [
      for (var i = 0; i < entries.length; i++)
        LeaderboardEntry(
          rank: i + 1,
          userId: entries[i].userId,
          username: entries[i].username,
          walletAddress: entries[i].walletAddress,
          points: entries[i].points,
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
    _held.update(quote.stock.mint, (v) => v + quote.estimatedShares, ifAbsent: () => quote.estimatedShares);
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
          challenger: _me(),
          opponent: rival,
          mode: mode,
          duration: duration,
          // Seeded rivals can't tap accept, so fixture mode starts duels at once.
          status: DuelStatus.active,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(duration),
          challengerReturnPct: 0,
          opponentReturnPct: 0,
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
            ? duel.copyWith(
                status: DuelStatus.active,
                startTime: now,
                endTime: now.add(duel.duration),
                challengerReturnPct: 0,
                opponentReturnPct: 0,
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
        final oldPrices = {for (final s in _stocks) s.mint: s.priceUsd};
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
        final newPrices = {for (final s in _stocks) s.mint: s.priceUsd};

        for (final mode in SportMode.values) {
          final roster = _rosters[mode]!;
          if (!roster.isEmpty) {
            final lineup = roster.lineup;
            final score = scoreWindow([
              for (var i = 0; i < roster.slots.length; i++)
                if (roster.slots[i].stock case final stock?)
                  SlotWindow(
                    startBalance: roster.slots[i].balance,
                    endBalance: _held[stock.mint] ?? 0,
                    startPrice: oldPrices[stock.mint]!,
                    endPrice: newPrices[stock.mint]!,
                    weight: lineup?.weightOf(i) ?? 1,
                    role: lineup == null ? null : footballSquadRoles[i],
                    benchOrder: lineup?.benchOrderOf(i),
                    isViceCaptain: lineup?.viceCaptain == i,
                  ),
            ]);
            _rosters[mode] = roster.copyWith(
              classicPoints: roster.classicPoints + score.points,
              lastReturnPct: score.returnPct,
              lastTickAt: DateTime.now(),
            );
          }
          _seedBoards[mode] = [
            for (final e in _seedBoards[mode]!)
              LeaderboardEntry(
                rank: 0,
                userId: e.userId,
                username: e.username,
                walletAddress: e.walletAddress,
                points: e.points + _rng.nextInt(61) - 25,
                streak: e.streak,
              ),
          ];
        }

        // Active duels accumulate this tick's return for both sides.
        for (var i = 0; i < _duels.length; i++) {
          final d = _duels[i];
          if (d.status != DuelStatus.active) continue;
          final mine = _rosters[d.mode]!.lastReturnPct;
          final theirs = (_rng.nextDouble() - 0.5) * 0.02;
          _duels[i] = d.copyWith(
            challengerReturnPct: (d.challengerReturnPct ?? 0) + (d.challenger.isCurrentUser ? mine : theirs),
            opponentReturnPct: (d.opponentReturnPct ?? 0) + (d.opponent.isCurrentUser ? mine : theirs),
          );
        }
        _notify();
      });

  @override
  Future<Duel> settleDuel(String duelId) => _delay(() {
        final i = _duels.indexWhere((d) => d.id == duelId);
        final d = _duels[i];
        final c = d.challengerReturnPct ?? 0;
        final o = d.opponentReturnPct ?? 0;
        final winner = c >= o ? d.challenger : d.opponent;
        _duels[i] = d.copyWith(
          status: DuelStatus.settled,
          endTime: DateTime.now(),
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
}
