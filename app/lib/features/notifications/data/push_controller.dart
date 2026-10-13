import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/core/utils/app_log.dart';
import 'package:formation/env/env.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/firebase_options.dart';

/// This device's FCM token, behind the Manager's permission.
abstract class PushClient {
  /// Asks for permission if needed and returns a token, or null if refused or
  /// unavailable here.
  Future<({String token, String platform})?> token();

  /// Fires when FCM rotates the token.
  Stream<String> get tokenRefresh;

  /// Fires when a push arrives while the app is open.
  Stream<void> get foreground;
}

/// FCM through firebase_messaging. Firebase is only initialised here, the
/// first time a Manager turns pushes on, so nothing else pays for it.
class FirebasePushClient implements PushClient {
  /// Web push uses the project's VAPID key, from FCM_VAPID_KEY in `app/.env`.
  static String get _vapidKey => Env.fcmVapidKey;

  Future<FirebaseMessaging> _messaging() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    return FirebaseMessaging.instance;
  }

  @override
  Future<({String token, String platform})?> token() async {
    final messaging = await _messaging();
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) return null;
    final token = await messaging.getToken(vapidKey: kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null);
    if (token == null) return null;
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android';
    return (token: token, platform: platform);
  }

  @override
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<void> get foreground => FirebaseMessaging.onMessage.map((_) {});
}

/// Turns pushes on and off for this device, and keeps its registration fresh.
///
/// The server decides what to push and when (categories, quiet hours, the
/// daily budget); this only makes sure it has somewhere to send them.
class PushController {
  PushController({
    required FormationRepository repository,
    required VoidCallback onMessage,
    PushClient? client,
  })  : _repository = repository,
        _onMessage = onMessage,
        _client = client ?? FirebasePushClient();

  static const _enabledKey = 'push_enabled_token';

  final FormationRepository _repository;
  final VoidCallback _onMessage;
  final PushClient _client;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// The token this device registered, if pushes are on here.
  Future<String?> enabledToken() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_enabledKey);
    } catch (_) {
      return null;
    }
  }

  /// Asks permission, registers this device, and starts listening. Returns
  /// false if the Manager refused or this platform can't receive pushes.
  Future<bool> enable() async {
    final result = await _client.token();
    if (result == null) return false;
    await _repository.registerPushDevice(
      token: result.token,
      platform: result.platform,
      timeZone: deviceTimeZone(),
    );
    await (await SharedPreferences.getInstance()).setString(_enabledKey, result.token);
    _listen(result.platform);
    return true;
  }

  Future<void> disable() async {
    final token = await enabledToken();
    if (token != null) await _repository.unregisterPushDevice(token);
    await (await SharedPreferences.getInstance()).remove(_enabledKey);
    await _cancel();
  }

  /// On launch: if pushes were on here, re-register (tokens rotate) quietly.
  Future<void> resume() async {
    if (await enabledToken() == null) return;
    try {
      await enable();
    } catch (e) {
      AppLog.warn('Push re-registration failed', e);
    }
  }

  void _listen(String platform) {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(_client.tokenRefresh.listen((token) async {
        await _repository.registerPushDevice(token: token, platform: platform, timeZone: deviceTimeZone());
        await (await SharedPreferences.getInstance()).setString(_enabledKey, token);
      }))
      // A push while the app is open: the bell should show it at once.
      ..add(_client.foreground.listen((_) => _onMessage()));
  }

  Future<void> _cancel() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> dispose() => _cancel();
}

/// The device's zone for quiet hours, as an IANA name. Flutter doesn't expose
/// the system's zone name, so this uses the fixed-offset Etc/GMT zones (whose
/// sign is inverted: UTC+1 is Etc/GMT-1). Half-hour zones fall back to UTC.
String deviceTimeZone([Duration? offset]) {
  final o = offset ?? DateTime.now().timeZoneOffset;
  if (o.inMinutes % 60 != 0) return 'UTC';
  final hours = o.inHours;
  if (hours == 0) return 'UTC';
  return 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
}
