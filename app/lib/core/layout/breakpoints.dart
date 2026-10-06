import 'package:flutter/widgets.dart';

/// How much room the app has to lay itself out in.
///
/// Named after window size rather than device type, because on web the two
/// come apart: a desktop browser at half width wants the phone layout, and a
/// tablet in landscape wants the wide one.
enum LayoutSize {
  /// Phones, and any narrow browser window. The layout the app was built for.
  compact,

  /// Large phones in landscape, small tablets, half-screen browsers.
  medium,

  /// Tablets in landscape and desktop browsers: room for two panes.
  expanded;

  bool get isCompact => this == LayoutSize.compact;

  /// True where a second pane fits beside the main one.
  bool get hasRoomForTwoPanes => this == LayoutSize.expanded;
}

/// Window-width thresholds, following the Material 3 window size classes.
abstract final class Breakpoints {
  /// Below this the app is a single full-bleed column.
  static const double medium = 600;

  /// At or above this there is room for a side rail and a second pane.
  static const double expanded = 1024;

  /// Widest the single-column layout is allowed to get.
  ///
  /// The pitch and the lineup rows are designed around a phone's proportions,
  /// and stretched across a desktop window they just look broken.
  static const double columnWidth = 640;

  /// Width of the detail pane in a two-pane layout.
  static const double detailPaneWidth = 420;

  static LayoutSize of(double width) {
    if (width >= expanded) return LayoutSize.expanded;
    if (width >= medium) return LayoutSize.medium;
    return LayoutSize.compact;
  }
}

extension LayoutSizeContext on BuildContext {
  /// The current [LayoutSize]. Rebuilds the caller when the window resizes,
  /// which on web happens whenever the player drags the window edge.
  LayoutSize get layoutSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
}
