import 'package:shared_preferences/shared_preferences.dart';

import 'package:formation/core/utils/app_log.dart';

/// The rank a Manager last saw on each board, remembered on this device, so
/// a move since yesterday can be shown when they come back, not only moves
/// made while the app is open.
abstract class RankMemory {
  Future<int?> read(String key);
  Future<void> write(String key, int rank);
}

class PrefsRankMemory implements RankMemory {
  const PrefsRankMemory();

  static const _prefix = 'formation.lastRank.';

  // Storage can be unavailable (private browsing); the board still works, it
  // just can't tell what changed since last time.
  @override
  Future<int?> read(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getInt('$_prefix$key');
    } catch (e) {
      AppLog.warn('Rank memory unavailable: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, int rank) async {
    try {
      await (await SharedPreferences.getInstance()).setInt('$_prefix$key', rank);
    } catch (e) {
      AppLog.warn('Rank memory unavailable: $e');
    }
  }
}
