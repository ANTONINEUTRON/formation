import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android/iOS: a WebView that renders the page and refuses to go anywhere.
/// JavaScript runs (for toggles inside the page) but no channel is added, so
/// nothing in the page can reach the app.
class SandboxedHtml extends StatefulWidget {
  const SandboxedHtml({required this.html, required this.height, super.key});

  final String html;
  final double height;

  @override
  State<SandboxedHtml> createState() => _SandboxedHtmlState();
}

class _SandboxedHtmlState extends State<SandboxedHtml> {
  late final WebViewController _controller;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          // The initial loadHtmlString arrives as about:blank / data:; anything
          // else is the page trying to leave, and it may not.
          onNavigationRequest: (request) =>
              request.url.startsWith('about:') || request.url.startsWith('data:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            if (mounted) setState(() => _loaded = true);
          },
        ),
      )
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
            // Let the page scroll itself instead of the chat claiming the drag.
            gestureRecognizers: const {
              Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
            },
          ),
          if (!_loaded) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
