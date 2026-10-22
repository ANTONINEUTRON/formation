import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Draws [card] off screen at [size] and hands it to the share sheet as a PNG,
/// with [text] alongside.
///
/// The card is laid out in an overlay entry pushed far outside the viewport,
/// so it renders with the app's theme and fonts but is never seen. [settle]
/// gives images inside it (the logo) a moment to decode before the capture.
Future<void> shareWidgetAsImage(
  BuildContext context, {
  required Widget card,
  required Size size,
  required String text,
  required String fileName,
  double pixelRatio = 2.7,
  Duration settle = const Duration(milliseconds: 250),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // Off screen, but still laid out and painted.
      left: -size.width * 4,
      top: 0,
      child: RepaintBoundary(
        key: boundaryKey,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox.fromSize(size: size, child: card),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(settle);
    await WidgetsBinding.instance.endOfFrame;

    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('The share card was not laid out');
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not encode the share card');

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
  } finally {
    entry.remove();
  }
}
