import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:solana/base58.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/core/utils/app_log.dart';
import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/data/session_store.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';

/// Signs on behalf of the connected wallet (implemented by WalletCubit via MWA).
abstract class WalletSigner {
  String get walletAddress;

  /// Returns the raw 64-byte ed25519 signature of [message].
  Future<Uint8List> signMessage(Uint8List message);

  /// Signs and submits a serialized transaction. Returns the base58 signature.
  Future<String> signAndSendTransaction(Uint8List transaction);

  /// A sign-in the wallet already signed while connecting, handed over once.
  ///
  /// Null when there is none, and then the challenge flow signs instead. On
  /// the web there usually is one, and spending it is what lets sign-in avoid
  /// a second wallet prompt — which Android Chrome would block.
  SignInProof? takeSignInProof();
}

/// [FormationRepository] backed by the NestJS API.
///
/// Signs in lazily on the first request: the wallet signs a one-time challenge
/// and the backend returns a bearer token, which is kept on disk until it
/// expires so a restart — or, on web, a page reload — does not cost the player
/// another wallet prompt.
class ApiRepository implements FormationRepository {
  ApiRepository({
    required String baseUrl,
    required WalletSigner signer,
    http.Client? client,
    SessionStore? sessions,
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _signer = signer,
        _http = client ?? http.Client(),
        _sessions = sessions ?? SessionStore();

  static const _adminKey = String.fromEnvironment('ADMIN_KEY');

  final String _baseUrl;
  final WalletSigner _signer;
  final http.Client _http;
  final SessionStore _sessions;
  final _changes = StreamController<void>.broadcast();

  String? _token;
  String _userId = '';
  Future<void>? _signingIn;

  @override
  String get currentUserId => _userId;

  @override
  Stream<void> get changes => _changes.stream;

  // ── Transport ──────────────────────────────────────────────────────────────

  Future<void> _ensureSignedIn() {
    if (_token != null) return Future.value();
    return _signingIn ??= _signIn().whenComplete(() => _signingIn = null);
  }

  Future<void> _signIn() async {
    // A token from a previous run beats asking the wallet to sign again.
    final stored = await _sessions.read(_signer.walletAddress);
    if (stored != null) {
      _token = stored.token;
      _userId = stored.userId;
      return;
    }

    // Signed in already, while connecting: one wallet prompt instead of two.
    final proof = _signer.takeSignInProof();
    if (proof != null) {
      try {
        final result = await _request('POST', '/auth/siws', auth: false, body: {
          'walletAddress': proof.address,
          'message': base64Encode(proof.signedMessage),
          'signature': base58encode(proof.signature),
        }) as Map<String, dynamic>;
        await _accept(result);
        return;
      } catch (e, s) {
        // Most likely a backend from before /auth/siws. The challenge flow
        // still works there, it just costs a second wallet prompt.
        AppLog.error('Sign In With Solana was refused; using the challenge', e, s);
      }
    }

    final challenge = await _request('POST', '/auth/challenge',
        body: {'walletAddress': _signer.walletAddress}, auth: false) as Map<String, dynamic>;
    final signature = await _signer.signMessage(
      Uint8List.fromList(utf8.encode(challenge['message'] as String)),
    );
    final result = await _request('POST', '/auth/verify', auth: false, body: {
      'walletAddress': _signer.walletAddress,
      'signature': base58encode(signature),
    }) as Map<String, dynamic>;
    await _accept(result);
  }

  /// Keeps the token from a successful sign-in, for this run and the next.
  Future<void> _accept(Map<String, dynamic> result) async {
    _token = result['token'] as String;
    _userId = (result['user'] as Map<String, dynamic>)['id'] as String;
    await _sessions.write(
      walletAddress: _signer.walletAddress,
      token: _token!,
      userId: _userId,
    );
  }

  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    if (auth) await _ensureSignedIn();
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({
        'content-type': 'application/json',
        if (auth && _token != null) 'authorization': 'Bearer $_token',
        ...headers,
      });
    if (body != null) request.body = jsonEncode(body);
    return _decode(method, path, await _send(request, auth: auth));
  }

  /// Sends [request] and turns transport failures and error statuses into
  /// exceptions a player can read. Shared by JSON, upload and image calls.
  Future<http.Response> _send(
    http.BaseRequest request, {
    bool auth = true,
    Duration timeout = AppConstants.apiTimeout,
  }) async {
    final method = request.method;
    final path = request.url.path;

    // Transport failures: no server, no DNS, no signal. The player only needs
    // to know it couldn't reach us; the cause is logged.
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      );
    } on TimeoutException catch (e, s) {
      AppLog.error('$method $path timed out', e, s);
      throw const NetworkException(
        message: "Formation isn't responding. Please try again.",
      );
    } catch (e, s) {
      AppLog.error('$method $path could not reach the server', e, s);
      throw const NetworkException(
        message: "Can't reach Formation. Check your connection and try again.",
      );
    }

    // A rejected token is worth nothing on the next request either, so drop
    // the stored copy too and let the wallet mint a fresh one.
    if (response.statusCode == 401 && auth) {
      _token = null;
      _sessions.clear().ignore();
    }
    if (response.statusCode >= 400) {
      Object? decoded;
      try {
        decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
      throw _failure(method, path, response.statusCode, decoded);
    }
    return response;
  }

  Object? _decode(String method, String path, http.Response response) {
    // A proxy or captive portal can return HTML where JSON is expected.
    try {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException catch (e, s) {
      AppLog.error('$method $path returned a non-JSON body', e, s);
      throw const NetworkException(
        message: 'Formation sent something unexpected. Please try again.',
      );
    }
  }

  /// Turns an error response into an exception whose message is safe to show.
  ///
  /// The backend writes its 4xx messages for players ("You do not hold AAPLx"),
  /// so those are passed through. A 5xx is our bug, not theirs, and gets a
  /// neutral line instead of whatever the stack trace said.
  AppException _failure(String method, String path, int status, Object? decoded) {
    final raw = decoded is Map ? decoded['message'] : null;
    final message = raw is List ? raw.join(', ') : raw as String?;
    AppLog.warn('$method $path failed with $status: ${message ?? "no message"}');

    // 502 and 503 are also how the backend says an upstream (the assistant's
    // model) failed or is switched off. Those messages are written for the
    // player — "you were not charged" — whereas a proxy's 502 has no message.
    if ((status == 502 || status == 503) && message != null) {
      return NetworkException(message: message, statusCode: status);
    }
    if (status >= 500) {
      return NetworkException(
        message: 'Formation is having trouble right now. Please try again shortly.',
        statusCode: status,
      );
    }
    if (status == 401) {
      return const AuthException(
        message: 'Your session expired. Reconnect your wallet to continue.',
      );
    }
    if (status == 404) {
      return NotFoundException(message: message ?? 'We could not find that.');
    }
    if (status == 402) {
      return ValidationException(
        message: message ?? 'You are out of Assistant Manager credits.',
        code: outOfCreditsCode,
      );
    }
    return ValidationException(message: message ?? 'That request was not accepted.');
  }


  void _notify() => _changes.add(null);

  Roster _roster(SportMode mode, Map<String, dynamic> json) =>
      Roster.fromJson(json, rosterShape(mode, json['formation'] as String?));

  // ── FormationRepository ────────────────────────────────────────────────────

  @override
  Future<List<XStock>> getXStocks() async {
    final list = (await _request('GET', '/xstocks', auth: false) as List)
        .cast<Map<String, dynamic>>();
    return list.map(XStock.fromJson).toList();
  }

  @override
  Future<Map<String, double>> getHeldBalances(List<String> mints) async {
    final json = await _request('GET', '/wallet/balances') as Map<String, dynamic>;
    final balances = (json['balances'] as Map<String, dynamic>)
        .map((mint, amount) => MapEntry(mint, (amount as num).toDouble()));
    return {for (final m in mints) if (balances.containsKey(m)) m: balances[m]!};
  }

  @override
  Future<Roster> getRoster(SportMode mode) async =>
      _roster(mode, await _request('GET', '/roster/${mode.apiValue}') as Map<String, dynamic>);

  @override
  Future<Roster> fillSlot(SportMode mode, int slotIndex, XStock stock) async {
    final json = await _request('PUT', '/roster/${mode.apiValue}/slots/$slotIndex',
        body: {'mint': stock.mint});
    _notify();
    return _roster(mode, json as Map<String, dynamic>);
  }

  @override
  Future<FormationChange> setFormation(SportMode mode, String formation) async {
    final json = await _request('PUT', '/roster/${mode.apiValue}/formation',
        body: {'formation': formation}) as Map<String, dynamic>;
    _notify();
    return FormationChange(
      roster: _roster(mode, json['roster'] as Map<String, dynamic>),
      dropped: [
        for (final s in (json['dropped'] as List).cast<Map<String, dynamic>>())
          XStock.fromJson(s),
      ],
    );
  }

  @override
  Future<Roster> setCaptaincy(
    SportMode mode, {
    int? captainSlot,
    int? viceCaptainSlot,
  }) async {
    final json = await _request('PUT', '/roster/${mode.apiValue}/captain', body: {
      'captainSlot': captainSlot,
      'viceCaptainSlot': viceCaptainSlot,
    });
    _notify();
    return _roster(mode, json as Map<String, dynamic>);
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    SportMode mode, {
    LeaguePeriod period = const LeaguePeriod.season(),
  }) async {
    final query = Uri(queryParameters: period.query).query;
    final list = await _request('GET', '/league/${mode.apiValue}?$query') as List;
    return list.cast<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList();
  }

  @override
  Future<MatchWeekResult> getMatchWeekResult(SportMode mode, {int? week}) async {
    final json = await _request(
      'GET',
      '/match-week/${mode.apiValue}/result${week == null ? '' : '?week=$week'}',
    ) as Map<String, dynamic>;
    return MatchWeekResult.fromJson(json);
  }

  @override
  Future<PortfolioHealth> getPortfolioHealth(SportMode mode) async => PortfolioHealth.fromJson(
        await _request('GET', '/match-week/${mode.apiValue}/health') as Map<String, dynamic>,
      );

  @override
  Future<List<PayToken>> getPayTokens() async {
    final list = await _request('GET', '/swap/tokens') as List;
    return list.cast<Map<String, dynamic>>().map(PayToken.fromJson).toList();
  }

  @override
  Future<SwapQuote> getSwapQuote(
    XStock stock,
    double amount, {
    PayToken payWith = PayToken.usdc,
  }) async {
    final json = await _request('POST', '/swap/quote', body: {
      'mint': stock.mint,
      'amount': amount,
      'payWith': payWith.symbol,
    });
    return SwapQuote.fromJson(stock, json as Map<String, dynamic>);
  }

  @override
  Future<double> executeSwap(SwapQuote quote) async {
    await _signAndConfirm(quote.quoteId);
    return quote.estimatedShares;
  }

  @override
  Future<Roster> fillFromHoldings(SportMode mode) async {
    final json = await _request('POST', '/roster/${mode.apiValue}/from-holdings');
    _notify();
    return _roster(mode, json as Map<String, dynamic>);
  }

  @override
  Future<SellQuote> getSellQuote(XStock stock, double shares) async {
    final json = await _request('POST', '/swap/sell-quote', body: {'mint': stock.mint, 'shares': shares});
    return SellQuote.fromJson(stock, json as Map<String, dynamic>);
  }

  @override
  Future<double> executeSell(SellQuote quote) async {
    await _signAndConfirm(quote.quoteId);
    return quote.estimatedUsdc;
  }

  /// Builds the quoted swap, has the wallet sign and send it, and waits for it to land.
  Future<void> _signAndConfirm(String? quoteId) async {
    final built = await _request('POST', '/swap/build', body: {'quoteId': quoteId}) as Map<String, dynamic>;
    final signature = await _signer.signAndSendTransaction(
      base64Decode(built['swapTransaction'] as String),
    );
    await _request('POST', '/swap/confirm', body: {'signature': signature});
    _notify();
  }

  // ── Leagues ────────────────────────────────────────────────────────────────

  @override
  Future<List<League>> getLeagues(SportMode mode) async {
    final list = await _request('GET', '/leagues?mode=${mode.apiValue}') as List;
    return list.cast<Map<String, dynamic>>().map(League.fromJson).toList();
  }

  @override
  Future<League> getLeague(String id) async {
    final json = await _request('GET', '/leagues/$id');
    return League.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<League> createLeague({
    required SportMode mode,
    required String name,
    required bool isPrivate,
    required DateTime startsAt,
    required Duration duration,
    int? maxMembers,
    String? opponent,
  }) async {
    final json = await _request('POST', '/leagues', body: {
      'name': name,
      'mode': mode.apiValue,
      'visibility': isPrivate ? 'private' : 'public',
      'startsAt': startsAt.toUtc().toIso8601String(),
      'durationHours': duration.inHours,
      if (maxMembers != null) 'maxMembers': maxMembers,
      if (opponent != null) 'opponent': opponent,
    });
    _notify();
    return League.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<League> joinLeague({String? id, String? code}) async {
    final json = await _request('POST', '/leagues/join', body: {
      if (id != null) 'id': id,
      if (code != null) 'code': code,
    });
    _notify();
    return League.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> leaveLeague(String id) async {
    await _request('DELETE', '/leagues/$id/membership');
    _notify();
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  @override
  Future<Profile> getProfile() async =>
      Profile.fromJson(await _request('GET', '/users/me') as Map<String, dynamic>);

  @override
  Future<Profile> updateProfile({String? username, String? bio, String? email}) async {
    final json = await _request('PATCH', '/users/me', body: {
      if (username != null) 'username': username,
      // An empty string is how the UI says "clear this"; null on the wire.
      if (bio != null) 'bio': bio.isEmpty ? null : bio,
      if (email != null) 'email': email.isEmpty ? null : email,
    });
    _notify();
    return Profile.fromJson(json as Map<String, dynamic>);
  }

  // ── Managers ───────────────────────────────────────────────────────────────

  @override
  Future<Manager> getManager(String userId, SportMode mode) async {
    final json = await _request('GET', '/managers/$userId?mode=${mode.apiValue}')
        as Map<String, dynamic>;
    // Their formation decides the shape their lineup slots map onto.
    return Manager.fromJson(json, rosterShape(mode, json['formation'] as String?));
  }

  @override
  Future<bool> setFollowing(String userId, {required bool following}) async {
    await _request(following ? 'POST' : 'DELETE', '/managers/$userId/follow');
    _notify();
    return following;
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  @override
  Future<List<AppNotification>> getNotifications() async {
    final list = await _request('GET', '/notifications') as List;
    return list.cast<Map<String, dynamic>>().map(AppNotification.fromJson).toList();
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    final json = await _request('GET', '/notifications/unread-count') as Map<String, dynamic>;
    return json['count'] as int;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _request('POST', '/notifications/$id/read');
    _notify();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _request('POST', '/notifications/read-all');
    _notify();
  }

  @override
  Future<void> registerPushDevice({required String token, required String platform, String? timeZone}) async {
    await _request('POST', '/notifications/devices', body: {
      'token': token,
      'platform': platform,
      'timeZone': ?timeZone,
    });
  }

  @override
  Future<void> unregisterPushDevice(String token) async {
    await _request('DELETE', '/notifications/devices/${Uri.encodeComponent(token)}');
  }

  @override
  Future<PushSettings> getPushSettings() async =>
      PushSettings.fromJson(await _request('GET', '/notifications/settings') as Map<String, dynamic>);

  @override
  Future<PushSettings> savePushSettings({
    Map<String, bool>? categories,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
    String? timeZone,
  }) async {
    final json = await _request('PUT', '/notifications/settings', body: {
      'categories': ?categories,
      'quietEnabled': ?quietEnabled,
      'quietStart': ?quietStart,
      'quietEnd': ?quietEnd,
      'timeZone': ?timeZone,
    });
    return PushSettings.fromJson(json as Map<String, dynamic>);
  }

  // ── Assistant Manager ──────────────────────────────────────────────────────

  @override
  Future<AssistantProfile> getAssistant() async =>
      AssistantProfile.fromJson(await _request('GET', '/assistant') as Map<String, dynamic>);

  @override
  Future<AssistantProfile> setAssistantCharacter(String characterId) async =>
      AssistantProfile.fromJson(
        await _request('PUT', '/assistant/character', body: {'characterId': characterId})
            as Map<String, dynamic>,
      );

  @override
  Future<AssistantReply> askAssistant(
    AssistantContext context,
    List<AssistantMessage> messages,
  ) async {
    final json = await _request('POST', '/assistant/chat', body: {
      'context': context.toJson(),
      'messages': [for (final m in messages) m.toJson()],
    });
    return AssistantReply.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<StarterSquad> draftStarterSquad(SportMode mode, {required double budgetUsd, String? style}) async {
    final json = await _request('POST', '/assistant/starter', body: {
      'mode': mode.apiValue,
      'budgetUsd': budgetUsd,
      'style': ?style,
    });
    return StarterSquad.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> dismissStarterSquad() async {
    await _request('POST', '/assistant/starter/dismiss');
  }

  @override
  Future<int> createAvatar({
    required Uint8List photo,
    required String mimeType,
    required String personality,
    String? name,
  }) async {
    await _ensureSignedIn();
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/assistant/avatar'))
      ..headers['authorization'] = 'Bearer $_token'
      ..fields.addAll({'personality': personality, 'consent': 'true', if (name != null && name.isNotEmpty) 'name': name})
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photo,
          filename: 'photo.${mimeType.split('/').last}',
          contentType: MediaType.parse(mimeType),
        ),
      );
    // Four images are drawn, one after another; give it room.
    final response = await _send(request, timeout: const Duration(minutes: 5));
    final json = _decode('POST', '/assistant/avatar', response) as Map<String, dynamic>;
    return (json['credits'] as num).toInt();
  }

  @override
  Future<Uint8List> avatarImage(AssistantPose pose) async {
    await _ensureSignedIn();
    final request = http.Request('GET', Uri.parse('$_baseUrl/assistant/avatar/${pose.name}'))
      ..headers['authorization'] = 'Bearer $_token';
    return (await _send(request)).bodyBytes;
  }

  @override
  Future<CreditQuote> quoteCredits(CreditPack pack) async {
    final json = await _request('POST', '/assistant/credits/quote', body: {'packId': pack.id});
    return CreditQuote.fromJson(pack, json as Map<String, dynamic>);
  }

  @override
  Future<int> buyCredits(CreditQuote quote) async {
    final built = await _request('POST', '/assistant/credits/build', body: {'quoteId': quote.quoteId})
        as Map<String, dynamic>;
    final signature = await _signer.signAndSendTransaction(
      base64Decode(built['transaction'] as String),
    );
    final confirmed = await _request('POST', '/assistant/credits/confirm', body: {
      'quoteId': quote.quoteId,
      'signature': signature,
    }) as Map<String, dynamic>;
    return (confirmed['credits'] as num).toInt();
  }

  // ── Demo controls ──────────────────────────────────────────────────────────

  Map<String, String> get _adminHeaders => {'x-admin-key': _adminKey};

  @override
  Future<void> runTick() async {
    await _request('POST', '/admin/tick', auth: false, headers: _adminHeaders);
    _notify();
  }

  @override
  Future<void> processLeagues() async {
    await _request('POST', '/admin/leagues/process', auth: false, headers: _adminHeaders);
    _notify();
  }

  @override
  Future<void> settleLeague(String id) async {
    await _request('POST', '/admin/leagues/$id/settle', auth: false, headers: _adminHeaders);
    _notify();
  }
}
