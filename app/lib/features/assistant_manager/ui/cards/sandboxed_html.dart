/// Shows an untrusted HTML document with no way out: an iframe without
/// same-origin on web, a WebView that refuses every navigation on Android.
///
/// The conditional export keeps `package:web` out of the Android build and
/// `webview_flutter` out of the web one. Both files define [SandboxedHtml].
library;

export 'package:formation/features/assistant_manager/ui/cards/sandboxed_html_io.dart'
    if (dart.library.js_interop) 'package:formation/features/assistant_manager/ui/cards/sandboxed_html_web.dart';
