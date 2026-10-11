import 'dart:typed_data';

import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
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

  /// Tokens this server accepts as payment, for the amount field's picker.
  Future<List<PayToken>> getPayTokens();

  /// Quotes buying [stock] by spending [amount] of [payWith].
  Future<SwapQuote> getSwapQuote(
    XStock stock,
    double amount, {
    PayToken payWith = PayToken.usdc,
  });

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

  // ── Assistant Manager ──────────────────────────────────────────────────────

  /// The chosen character (null until picked), the presets, and credits.
  Future<AssistantProfile> getAssistant();

  Future<AssistantProfile> setAssistantCharacter(String characterId);

  /// One reply to the conversation so far. Costs a credit; throws a
  /// [ValidationException] with [outOfCreditsCode] when there are none.
  Future<AssistantReply> askAssistant(AssistantContext context, List<AssistantMessage> messages);

  /// The Assistant Manager drafts a complete starter squad for [mode]. Free,
  /// once plus one regenerate.
  Future<StarterSquad> draftStarterSquad(SportMode mode, {required double budgetUsd, String? style});

  /// The Manager will build their own team; the free starter draft is used up.
  Future<void> dismissStarterSquad();

  /// Draws a custom Assistant Manager from [photo], with the voice of the
  /// preset [personality]. Free the first time, then credits. The photo isn't
  /// kept. Returns the credit balance after.
  Future<int> createAvatar({
    required Uint8List photo,
    required String mimeType,
    required String personality,
    String? name,
  });

  /// The Manager's own custom avatar in [pose].
  Future<Uint8List> avatarImage(AssistantPose pose);

  /// Prices [pack] in SKR at the live rate, held for a couple of minutes.
  Future<CreditQuote> quoteCredits(CreditPack pack);

  /// Pays for [quote] from the wallet (the Manager signs) and returns the new
  /// credit balance once the payment is confirmed on-chain.
  Future<int> buyCredits(CreditQuote quote);

  // ── Demo controls (debug builds only) ─────────────────────────────────────

  /// Records prices now and banks everything owed since the last tick.
  Future<void> runTick();

  /// Opens scheduled leagues and settles finished ones without waiting.
  Future<void> processLeagues();

  /// Settles a league now instead of waiting for its end time.
  Future<void> settleLeague(String id);
}
