import 'package:symbians/features/shared/domain/models.dart';

/// Everything the Formation UI needs, independent of where it comes from.
///
/// [FixtureRepository] serves in-memory data for building and demoing the UI;
/// [ApiRepository] talks to the NestJS backend, which owns all scoring.
abstract class FormationRepository {
  /// Backend user id of the signed-in player.
  String get currentUserId;

  /// Emits after any mutation (draft, duel, tick) so open screens can reload.
  Stream<void> get changes;

  Future<List<XStock>> getXStocks();

  /// Token balances held by the connected wallet, keyed by mint.
  Future<Map<String, double>> getHeldBalances(List<String> mints);

  /// The user's team for [mode], with its live gameweek.
  Future<Roster> getRoster(SportMode mode);

  /// Puts [stock] into slot [slotIndex], using the wallet's real balance.
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock);

  /// Football only: changes shape. Picks that no longer fit come off the team
  /// and are returned as `dropped`. Applies from the next gameweek.
  Future<FormationChange> setFormation(SportMode mode, String formation);

  /// Football and basketball: the captain scores a multiplier.
  Future<Roster> setCaptaincy(SportMode mode, {int? captainSlot, int? viceCaptainSlot});

  Future<List<LeaderboardEntry>> getLeaderboard(SportMode mode);

  Future<SwapQuote> getSwapQuote(XStock stock, double usdcAmount);

  /// Buys the quoted stock. Returns the number of shares received.
  Future<double> executeSwap(SwapQuote quote);

  Future<List<Duel>> getDuels(SportMode mode);

  /// Challenges [opponent] (wallet address or username).
  Future<Duel> createDuel({
    required SportMode mode,
    required String opponent,
    required Duration duration,
  });

  Future<Duel> respondToDuel(String duelId, {required bool accept});

  Future<List<Trophy>> getTrophies();

  // ── Demo controls (debug builds only) ─────────────────────────────────────

  /// Records prices now and rescores the live gameweek.
  Future<void> runTick();

  /// Closes the current gameweek early and opens the next.
  Future<void> advanceGameweek(SportMode mode);

  /// Settles an active duel now instead of waiting for its end time.
  Future<Duel> settleDuel(String duelId);
}
