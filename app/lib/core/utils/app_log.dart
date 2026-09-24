import 'dart:developer' as developer;

/// Application logging.
///
/// Errors go here in full, with their stack trace, and never to the screen.
/// The UI shows a short sentence instead — see `errorText` in format.dart.
/// Uses `dart:developer` rather than `print` so entries carry a level and a
/// name, survive release builds, and show up in `flutter logs` and logcat.
abstract final class AppLog {
  static const _name = 'formation';

  /// Level values follow package:logging, which DevTools colours by severity.
  static const _info = 800;
  static const _warning = 900;
  static const _severe = 1000;

  static void info(String message) =>
      developer.log(message, name: _name, level: _info);

  static void warn(String message, [Object? error]) =>
      developer.log(message, name: _name, level: _warning, error: error);

  /// The full detail of a failure: what we were doing, and what went wrong.
  static void error(String context, Object error, [StackTrace? stackTrace]) =>
      developer.log(
        context,
        name: _name,
        level: _severe,
        error: error,
        stackTrace: stackTrace ?? StackTrace.current,
      );
}
