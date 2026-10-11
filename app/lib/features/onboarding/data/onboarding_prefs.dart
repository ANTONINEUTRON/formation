import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/core/utils/app_log.dart';

/// What onboarding remembers on this device.
///
/// The intro is shown once; after that a Manager reconnecting a wallet goes
/// straight to the connect screen. The Assistant Manager picked during the
/// intro is held here until there's a session to save it to.
class OnboardingPrefs {
  static const _seenKey = 'formation.onboarding.seen';
  static const _characterKey = 'formation.onboarding.character';
  static const _starterOfferedKey = 'formation.onboarding.starterOffered';

  Future<bool> introSeen() => _read((p) => p.getBool(_seenKey) ?? false, false);

  Future<void> markIntroSeen() => _write((p) => p.setBool(_seenKey, true));

  Future<String?> pendingCharacter() => _read((p) => p.getString(_characterKey), null);

  Future<void> setPendingCharacter(String id) => _write((p) => p.setString(_characterKey, id));

  Future<void> clearPendingCharacter() => _write((p) => p.remove(_characterKey));

  /// Whether the free starter squad has been offered on this device already,
  /// so closing it doesn't bring it back on every launch.
  Future<bool> starterOffered() => _read((p) => p.getBool(_starterOfferedKey) ?? false, false);

  Future<void> markStarterOffered() => _write((p) => p.setBool(_starterOfferedKey, true));

  // Storage can be unavailable (private browsing); onboarding still works,
  // it just won't remember.
  Future<T> _read<T>(T Function(SharedPreferences) read, T fallback) async {
    try {
      return read(await SharedPreferences.getInstance());
    } catch (e) {
      AppLog.warn('Onboarding prefs unavailable: $e');
      return fallback;
    }
  }

  Future<void> _write(Future<Object?> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (e) {
      AppLog.warn('Onboarding prefs unavailable: $e');
    }
  }
}
