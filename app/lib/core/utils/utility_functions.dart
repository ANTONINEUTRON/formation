import 'package:uuid/uuid.dart';

/// Utility functions used across the app.
class UtilityFunctions {
  UtilityFunctions._();

  static const _uuid = Uuid();

  /// Generates a new UUID v4.
  static String generateId() => _uuid.v4();

  /// Capitalizes the first letter of a string.
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Truncates a string to the specified length with ellipsis.
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Formats a number with thousand separators.
  static String formatNumber(num value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  /// Returns true if the string is a valid email.
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Debounces a function call.
  static Future<void> debounce(
    Duration duration,
    void Function() callback,
  ) async {
    await Future.delayed(duration);
    callback();
  }
}
