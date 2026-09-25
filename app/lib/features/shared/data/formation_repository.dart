import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Everything the Formation UI needs, independent of where it comes from.
///
/// [FixtureRepository] serves in-memory data for building and demoing the UI;
/// [ApiRepository] talks to the NestJS backend, which owns all scoring.
abstract class FormationRepository {
  /// Backend user id of the signed-in player.
  String get currentUserId;

  /// Emits after any mutation (draft, substitution, tick) so screens reload.
  Stream<void> get changes;

  Future<List<XStock>> getXStocks();

  /// Token balances held by the connected wallet, keyed by mint.
  Future<Map<String, double>> getHeldBalances(List<String> mints);

  /// The user's team for [mode], with its live session and bench.
  Future<Roster> getRoster(SportMode mode);

  /// Puts [stock] into slot [slotIndex], using the wallet's real balance.
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock);

  /// Football only: changes shape. Picks that no longer fit come off the team
  /// and are returned as `dropped`.
  Future<FormationChange> setFormation(SportMode mode, String formation);

  /// Football and basketball: the captain scores a multiplier.
  Future<Roster> setCaptaincy(SportMode mode, {int? captainSlot, int? viceCaptainSlot});

  /// Standings for [mode] over [period], defaulting to the all-time board.
  Future<List<LeaderboardEntry>> getLeaderboard(
    SportMode mode, {
    LeaguePeriod period = const LeaguePeriod.allTime(),
  });

  Future<SwapQuote> getSwapQuote(XStock stock, double usdcAmount);

  /// Buys the quoted stock. Returns the number of shares received.
  Future<double> executeSwap(SwapQuote quote);

  // ── Leagues (custom leagues and PvP duels are the same object) ───────────

  /// Public leagues open to join, plus every league the player is in.
  Future<List<League>> getLeagues(SportMode mode);

  Future<League> getLeague(String id);

  /// Creates a league. Pass [opponent] with `maxMembers: 2` for a PvP duel.
  Future<League> createLeague({
    required SportMode mode,
    required String name,
    required bool isPrivate,
    required DateTime startsAt,
    required Duration duration,
    int? maxMembers,
    String? opponent,
  });

  /// Joins by id (public) or by shareable code.
  Future<League> joinLeague({String? id, String? code});

  Future<void> leaveLeague(String id);

  // ── Profile ────────────────────────────────────────────────────────────────

  /// The signed-in player's own profile, including their private email.
  Future<Profile> getProfile();

  /// Updates name, bio and email. Omit a field to leave it alone; pass an
  /// empty string to clear the bio or email.
  Future<Profile> updateProfile({String? username, String? bio, String? email});

  // ── Managers ───────────────────────────────────────────────────────────────

  /// Another player's profile, lineup and holdings for [mode].
  Future<Manager> getManager(String userId, SportMode mode);

  /// Follows or unfollows a manager. Returns the new state.
  Future<bool> setFollowing(String userId, {required bool following});

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<List<AppNotification>> getNotifications();

  /// Unread count for the bell badge.
  Future<int> getUnreadNotificationCount();

  Future<void> markNotificationRead(String id);

  Future<void> markAllNotificationsRead();

  // ── Demo controls (debug builds only) ─────────────────────────────────────

  /// Records prices now and banks everything owed since the last tick.
  Future<void> runTick();

  /// Opens scheduled leagues and settles finished ones without waiting.
  Future<void> processLeagues();

  /// Settles a league now instead of waiting for its end time.
  Future<void> settleLeague(String id);
}
