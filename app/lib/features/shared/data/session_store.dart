import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/core/utils/app_log.dart';

/// A signed-in session restored from disk.
class StoredSession {
  const StoredSession({required this.token, required this.userId});

  final String token;
  final String userId;
}

/// Persists the backend bearer token between app launches.
///
/// Without this the app signs in again on every launch, which means a wallet
/// prompt every time — tolerable on Android, where connecting already opens
/// the wallet, but on web a page reload would ask for a signature, and players
/// reload pages.
///
/// Only one session is kept, tagged with the wallet that owns it, so switching
/// wallets cannot inherit the previous player's token.
class SessionStore {
  static const _tokenKey = 'formation.auth.token';
  static const _userIdKey = 'formation.auth.userId';
  static const _walletKey = 'formation.auth.wallet';

  /// Returns the stored session for [walletAddress], or null when there is
  /// none, it belongs to another wallet, or it has expired.
  Future<StoredSession?> read(String walletAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userId = prefs.getString(_userIdKey);
      final wallet = prefs.getString(_walletKey);

      if (token == null || userId == null || wallet != walletAddress) {
        return null;
      }
      if (_isExpired(token)) {
        await clear();
        return null;
      }
      return StoredSession(token: token, userId: userId);
    } catch (e, s) {
      // Private browsing, blocked site data, a corrupt store: all mean "sign
      // in again", never "fail to start".
      AppLog.error('SessionStore.read failed', e, s);
      return null;
    }
  }

  Future<void> write({
    required String walletAddress,
    required String token,
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_walletKey, walletAddress);
    } catch (e, s) {
      // The session still works for this run; it just won't survive a restart.
      AppLog.error('SessionStore.write failed', e, s);
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_walletKey);
    } catch (e, s) {
      AppLog.error('SessionStore.clear failed', e, s);
    }
  }

  /// Reads `exp` out of the backend's `base64url(payload).signature` token.
  ///
  /// Checking it here saves a round trip that would come back 401 anyway. A
  /// token we cannot parse is treated as expired: the signature is the real
  /// gate, so the worst case is one unnecessary sign-in.
  static bool _isExpired(String token) {
    try {
      final body = token.split('.').first;
      final padded = body.padRight((body.length + 3) & ~3, '=');
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      final exp = payload['exp'] as num?;
      if (exp == null) return true;
      // Expire a minute early so a token cannot die mid-request.
      return DateTime.now().millisecondsSinceEpoch > exp - 60_000;
    } catch (_) {
      return true;
    }
  }
}
