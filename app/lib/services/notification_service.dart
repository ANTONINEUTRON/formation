import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart' as styled_toast;

import 'package:formation/core/theme/theme.dart';

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

  /// An in-app notification, popped in at the top for a few seconds: the
  /// title, the body, and a tap through to the inbox.
  static void showNotification(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 6),
  }) {
    styled_toast.showToastWidget(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                color: AppColors.surfaceElevated,
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    styled_toast.dismissAllToast();
                    onTap?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      context: context,
      position: styled_toast.StyledToastPosition.top,
      animation: styled_toast.StyledToastAnimation.slideFromTop,
      reverseAnimation: styled_toast.StyledToastAnimation.fade,
      duration: duration,
      // Taps reach the card, so it can open the inbox.
      isIgnoring: false,
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
