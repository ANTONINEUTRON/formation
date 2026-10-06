/// Startup work that only means something in a browser.
///
/// The implementation is chosen at compile time so the Android build never
/// pulls in `flutter_web_plugins`, whose url strategy library is web-only.
library;

export 'package:formation/core/web/web_entry_noop.dart'
    if (dart.library.js_interop) 'package:formation/core/web/web_entry_web.dart';
