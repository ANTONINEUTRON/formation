import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:solana/base58.dart';

import 'package:symbians/core/constants/app_constants.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/domain/roster_shapes.dart';

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

    final response = await http.Response.fromStream(
      await _http.send(request).timeout(AppConstants.apiTimeout),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode == 401 && auth) _token = null;
    if (response.statusCode >= 400) {
      final message = decoded is Map ? decoded['message'] : null;
      throw StateError(message is List
          ? message.join(', ')
          : '${message ?? 'Request failed (${response.statusCode})'}');
    }
    return decoded;
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
  Future<List<LeaderboardEntry>> getLeaderboard(SportMode mode) async {
    final list = await _request('GET', '/league/${mode.apiValue}') as List;
    return list.cast<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList();
  }

  @override
  Future<SwapQuote> getSwapQuote(XStock stock, double usdcAmount) async {
    final json = await _request('POST', '/swap/quote',
        body: {'mint': stock.mint, 'usdcAmount': usdcAmount});
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

  @override
  Future<List<Duel>> getDuels(SportMode mode) async {
    final list = await _request('GET', '/duels?mode=${mode.apiValue}') as List;
    return list.cast<Map<String, dynamic>>().map(Duel.fromJson).toList();
  }

  @override
  Future<Duel> createDuel({
    required SportMode mode,
    required String opponent,
    required Duration duration,
  }) async {
    final json = await _request('POST', '/duels', body: {
      'mode': mode.apiValue,
      'opponent': opponent,
      'durationHours': duration.inHours,
    });
    _notify();
    return Duel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Duel> respondToDuel(String duelId, {required bool accept}) async {
    final json = await _request('POST', '/duels/$duelId/${accept ? 'accept' : 'decline'}');
    _notify();
    return Duel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<Trophy>> getTrophies() async {
    final list = await _request('GET', '/trophies') as List;
    return list.cast<Map<String, dynamic>>().map(Trophy.fromJson).toList();
  }

  // ── Demo controls ──────────────────────────────────────────────────────────

  Map<String, String> get _adminHeaders => {'x-admin-key': _adminKey};

  @override
  Future<void> runTick() async {
    await _request('POST', '/admin/tick', auth: false, headers: _adminHeaders);
    _notify();
  }

  @override
  Future<void> advanceGameweek(SportMode mode) async {
    await _request('POST', '/admin/gameweeks/${mode.apiValue}/advance',
        auth: false, headers: _adminHeaders);
    _notify();
  }

  @override
  Future<Duel> settleDuel(String duelId) async {
    final json = await _request('POST', '/admin/duels/$duelId/settle',
        auth: false, headers: _adminHeaders) as Map<String, dynamic>;
    final mode = SportMode.fromApi(json['mode'] as String);
    _notify();
    // The admin response has no viewer; re-read so "me" and "iWon" resolve.
    return (await getDuels(mode)).firstWhere((d) => d.id == duelId);
  }
}
