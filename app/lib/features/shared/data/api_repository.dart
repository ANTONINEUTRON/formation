import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:solana/base58.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/core/utils/app_log.dart';
import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';

/// Signs on behalf of the connected wallet (implemented by WalletCubit via MWA).
abstract class WalletSigner {
  String get walletAddress;

  /// Returns the raw 64-byte ed25519 signature of [message].
  Future<Uint8List> signMessage(Uint8List message);

  /// Signs and submits a serialized transaction. Returns the base58 signature.
  Future<String> signAndSendTransaction(Uint8List transaction);
}

/// [FormationRepository] backed by the NestJS API.
///
/// Signs in lazily on the first request: the wallet signs a one-time challenge
/// and the backend returns a bearer token kept for the app session.
class ApiRepository implements FormationRepository {
  ApiRepository({
    required String baseUrl,
    required WalletSigner signer,
    http.Client? client,
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _signer = signer,
        _http = client ?? http.Client();

  static const _adminKey = String.fromEnvironment('ADMIN_KEY');

  final String _baseUrl;
  final WalletSigner _signer;
  final http.Client _http;
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
    final challenge = await _request('POST', '/auth/challenge',
        body: {'walletAddress': _signer.walletAddress}, auth: false) as Map<String, dynamic>;
    final signature = await _signer.signMessage(
      Uint8List.fromList(utf8.encode(challenge['message'] as String)),
    );
    final result = await _request('POST', '/auth/verify', auth: false, body: {
      'walletAddress': _signer.walletAddress,
      'signature': base58encode(signature),
    }) as Map<String, dynamic>;
    _token = result['token'] as String;
    _userId = (result['user'] as Map<String, dynamic>)['id'] as String;
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

    // Transport failures: no server, no DNS, no signal. The player only needs
    // to know it couldn't reach us; the cause is logged.
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(AppConstants.apiTimeout),
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

    // A proxy or captive portal can return HTML where JSON is expected.
    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException catch (e, s) {
      AppLog.error('$method $path returned a non-JSON body', e, s);
      throw const NetworkException(
        message: 'Formation sent something unexpected. Please try again.',
      );
    }

    if (response.statusCode == 401 && auth) _token = null;
    if (response.statusCode >= 400) {
      throw _failure(method, path, response.statusCode, decoded);
    }
    return decoded;
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
    LeaguePeriod period = const LeaguePeriod.allTime(),
  }) async {
    final query = Uri(queryParameters: period.query).query;
    final list = await _request('GET', '/league/${mode.apiValue}?$query') as List;
    return list.cast<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList();
  }

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
    final built = await _request('POST', '/swap/build', body: {'quoteId': quote.quoteId})
        as Map<String, dynamic>;
    final signature = await _signer.signAndSendTransaction(
      base64Decode(built['swapTransaction'] as String),
    );
    await _request('POST', '/swap/confirm', body: {'signature': signature});
    _notify();
    return quote.estimatedShares;
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
