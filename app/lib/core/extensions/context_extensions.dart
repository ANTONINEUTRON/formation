import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart' as styled_toast;

import 'package:formation/services/notification_service.dart';

/// Extension methods for [BuildContext].
extension ContextExtensions on BuildContext {
  // Theme shortcuts
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;

  // Media Query shortcuts
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get viewInsets => mediaQuery.viewInsets;
  EdgeInsets get viewPadding => mediaQuery.viewPadding;

  // Platform brightness
  bool get isDarkMode => mediaQuery.platformBrightness == Brightness.dark;

  // Responsive breakpoints
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  // Navigation shortcuts
  void pop<T>([T? result]) => Navigator.of(this).pop(result);
  void popUntilRoot() => Navigator.of(this).popUntil((route) => route.isFirst);

  // --- Toast/Notification methods ---

  /// Shows a toast with the given message and type.
  void showToast({
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    styled_toast.StyledToastPosition position =
        styled_toast.StyledToastPosition.bottom,
  }) {
    NotificationService.showToast(
      this,
      message: message,
      type: type,
      duration: duration,
      position: position,
    );
  }

  /// Shows a success toast.
  void showSuccessToast({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    NotificationService.showSuccess(this, message: message, duration: duration);
  }

  /// Shows an error toast.
  void showErrorToast({
    required String message,
    Duration duration = const Duration(seconds: 6),
  }) {
    NotificationService.showError(this, message: message, duration: duration);
  }

  /// Shows an info toast.
  void showInfoToast({
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    NotificationService.showInfo(this, message: message, duration: duration);
  }

  /// Shows a warning toast.
  void showWarningToast({
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    NotificationService.showWarning(this, message: message, duration: duration);
  }
}
