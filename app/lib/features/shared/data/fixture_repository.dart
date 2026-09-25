import 'dart:async';
import 'dart:math';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/domain/entity/notification.dart';
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
      final names = List.of(seedUsernames)..shuffle(_rng);
      _seedBoards[mode] = [
        for (var i = 0; i < 30; i++)
          LeaderboardEntry(
            rank: 0,
            userId: 'seed-${mode.apiValue}-$i',
            username: names[i],
            walletAddress: _fakeAddress(),
            points: (600 - i * 19 + _rng.nextInt(15)).toDouble(),
            todayPoints: (_rng.nextInt(70) - 25).toDouble(),
            streak: _rng.nextInt(6),
          ),
      ];
    }

    // Football arrives pre-drafted so League and Team have content;
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
      entered: roster.isComplete,
      points: 0,
      slots: const [],
      teamEvents: const [],
      substitutionsUsed: 0,
      freeSubstitutionsLeft: 3,
    );
  }

  /// Scores the live session: alpha against SPYx, plus a few role events.
  void _rescore(SportMode mode) {
    final session = _sessions[mode];
    final roster = _rosters[mode]!;
    if (session == null || !roster.isComplete) return;

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

    _sessions[mode] = Session(
      startsAt: session.startsAt,
      endsAt: session.endsAt,
      entered: true,
      // Continuous banking: today's points accumulate rather than reset.
      points: _round1(slots.fold<double>(0, (sum, s) => sum + s.total)),
      slots: slots,
      teamEvents: const [],
      substitutionsUsed: session.substitutionsUsed,
      freeSubstitutionsLeft: session.freeSubstitutionsLeft,
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
                'needs a ${slot.position.requiredTier?.label.toLowerCase()} stock',
          );
        }
        if (balance <= 0) throw ValidationException(message: 'You do not hold ${stock.symbol}');
        if (roster.slots.any((s) => s.stock?.mint == stock.mint)) {
          throw ValidationException(message: '${stock.symbol} is already on this team');
        }
        final slots = List.of(roster.slots)..[slotIndex] = slot.fill(stock, balance);
        _rosters[mode] = roster.copyWith(slots: slots);
        if (_rosters[mode]!.isComplete && _sessions[mode] == null) {
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
    LeaguePeriod period = const LeaguePeriod.allTime(),
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
