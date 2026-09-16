import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Everything the Formation UI needs, independent of where it comes from.
///
/// [FixtureRepository] serves in-memory data for building and demoing the UI;
/// [ApiRepository] talks to the NestJS backend. Widgets and cubits depend only
/// on this interface.
abstract class FormationRepository {
  /// Backend user id of the signed-in player.
  String get currentUserId;

  /// Emits after any mutation (draft, duel, tick) so open screens can reload.
  Stream<void> get changes;

  Future<List<XStock>> getXStocks();

  /// Token balances held by the connected wallet, keyed by mint.
  Future<Map<String, double>> getHeldBalances(List<String> mints);

  /// The user's roster for [mode]. Returns an empty roster if never drafted.
  Future<Roster> getRoster(SportMode mode);

  /// Puts [stock] into slot [slotIndex], using the wallet's real balance.
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock);

  /// Football only: saves the starting XI, bench order and armbands.
  /// Takes effect from the next scoring tick.
  Future<Roster> setLineup(SportMode mode, Lineup lineup);

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

  /// Runs the hourly Classic scoring tick now.
  Future<void> runTick();

  /// Settles an active duel now instead of waiting for its end time.
  Future<Duel> settleDuel(String duelId);
}
