import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart' as styled_toast;

import 'package:symbians/core/theme/theme.dart';

/// Types of notifications.
enum NotificationType { success, error, info, warning }

/// Service for showing toast notifications and snackbars.
class NotificationService {
  /// Shows a styled toast notification.
  static void showToast(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    styled_toast.StyledToastPosition position =
        styled_toast.StyledToastPosition.bottom,
  }) {
    final backgroundColor = _getBackgroundColor(type);

    styled_toast.showToast(
      message,
      context: context,
      position: position,
      duration: duration,
      backgroundColor: backgroundColor,
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      borderRadius: BorderRadius.circular(8),
      textPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  /// Shows a success toast.
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showToast(
      context,
      message: message,
      type: NotificationType.success,
      duration: duration,
    );
  }

  /// Shows an error toast.
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 6),
  }) {
    showToast(
      context,
      message: message,
      type: NotificationType.error,
      duration: duration,
    );
  }

  /// Shows an info toast.
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    showToast(
      context,
      message: message,
      type: NotificationType.info,
      duration: duration,
    );
  }

  /// Shows a warning toast.
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    showToast(
      context,
      message: message,
      type: NotificationType.warning,
      duration: duration,
    );
  }

  static Color _getBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.error:
        return AppColors.error;
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.info:
        return AppColors.surface;
    }
  }
}
