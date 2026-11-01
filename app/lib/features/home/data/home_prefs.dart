import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/core/utils/app_log.dart';
import 'package:formation/features/shared/domain/models.dart';

/// What the home screen remembers on this device: the sport tab the Manager
/// was last on, so the app reopens where they left it.
class HomePrefs {
  static const _sportKey = 'formation.home.sport';

  /// The last sport picked; null before the first pick or for a value this
  /// version doesn't know.
  Future<SportMode?> lastSport() async {
    try {
      return SportMode.tryFromApi((await SharedPreferences.getInstance()).getString(_sportKey));
    } catch (e) {
      // Storage can be unavailable (private browsing); the app opens on football.
      AppLog.warn('Home prefs unavailable: $e');
      return null;
    }
  }

  Future<void> setLastSport(SportMode mode) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_sportKey, mode.apiValue);
    } catch (e) {
      AppLog.warn('Home prefs unavailable: $e');
    }
  }
}
