import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web: an iframe with `sandbox="allow-scripts"` and no `allow-same-origin`,
/// so the page runs in an opaque origin: it can't read the app's storage,
/// cookies or session, open popups, submit forms or navigate the app. Its
/// own CSP (added by the server) also blocks every network request.
class SandboxedHtml extends StatefulWidget {
  const SandboxedHtml({required this.html, required this.height, super.key});

  final String html;
  final double height;

  @override
  State<SandboxedHtml> createState() => _SandboxedHtmlState();
}

class _SandboxedHtmlState extends State<SandboxedHtml> {
  static var _next = 0;
  late final String _viewType = 'assistant-html-${_next++}';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      return web.HTMLIFrameElement()
        ..setAttribute('sandbox', 'allow-scripts')
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..srcdoc = widget.html.toJS
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
