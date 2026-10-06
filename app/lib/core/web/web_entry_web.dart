import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:formation/core/route/pending_deep_link.dart';

/// Switches the browser to real paths and remembers where the player landed.
///
/// Without the path strategy every URL carries a `#`, which breaks the
/// server-side share previews: Firebase Hosting never sees the fragment, so
/// `/managers/<id>` could not be rewritten to the renderer that injects the
/// Open Graph tags.
void configureWebEntry() {
  usePathUrlStrategy();
  PendingDeepLink.capture();
}
