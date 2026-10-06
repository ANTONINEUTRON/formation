/// Holds the URL the player arrived on until the router is ready for it.
///
/// A shared link like `/managers/<id>` opens the app disconnected, which shows
/// onboarding rather than the router — so by the time there is a router to
/// navigate, the deep link has to come from somewhere other than the platform.
/// It is captured once at startup and handed over on first use.
abstract final class PendingDeepLink {
  static String? _path;

  /// Records the current browser location, ignoring the bare root.
  static void capture() {
    final uri = Uri.base;
    final path = uri.path;
    if (path.isEmpty || path == '/') return;
    _path = uri.hasQuery ? '$path?${uri.query}' : path;
  }

  /// Returns the captured location once, then null on every later call.
  static String? take() {
    final path = _path;
    _path = null;
    return path;
  }
}
