import 'package:flutter/widgets.dart';

/// Extension methods for widgets.
extension WidgetHelpers on Widget {
  /// Wraps widget with padding
  Widget padded(EdgeInsets padding) => Padding(padding: padding, child: this);

  /// Wraps widget with horizontal padding
  Widget paddedH(double value) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: value), child: this);

  /// Wraps widget with vertical padding
  Widget paddedV(double value) =>
      Padding(padding: EdgeInsets.symmetric(vertical: value), child: this);

  /// Wraps widget with all-sides padding
  Widget paddedAll(double value) =>
      Padding(padding: EdgeInsets.all(value), child: this);

  /// Wraps widget in Center
  Widget centered() => Center(child: this);

  /// Wraps widget in Expanded
  Widget expanded({int flex = 1}) => Expanded(flex: flex, child: this);

  /// Wraps widget in Flexible
  Widget flexible({int flex = 1, FlexFit fit = FlexFit.loose}) =>
      Flexible(flex: flex, fit: fit, child: this);

  /// Wraps widget in SizedBox with width
  Widget withWidth(double width) => SizedBox(width: width, child: this);

  /// Wraps widget in SizedBox with height
  Widget withHeight(double height) => SizedBox(height: height, child: this);

  /// Wraps widget in SizedBox with width and height
  Widget withSize(double width, double height) =>
      SizedBox(width: width, height: height, child: this);

  /// Wraps widget in Opacity
  Widget withOpacity(double opacity) => Opacity(opacity: opacity, child: this);

  /// Wraps widget in IgnorePointer
  Widget ignorePointer({bool ignoring = true}) =>
      IgnorePointer(ignoring: ignoring, child: this);

  /// Wraps widget in AbsorbPointer
  Widget absorbPointer({bool absorbing = true}) =>
      AbsorbPointer(absorbing: absorbing, child: this);
}
