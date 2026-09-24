import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';

/// A reusable rounded form field with validation support.
class RoundedFormField extends FormField<String> {
  RoundedFormField({
    super.key,
    super.initialValue = '',
    super.onSaved,
    super.validator,
    TextEditingController? controller,
    FocusNode? focusNode,
    String hintText = 'Enter text',
    int? maxLines = 1,
    int? minLines,
    double maxHeight = 100,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    bool autofocus = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    double borderRadius = 55,
    Color? backgroundColor,
    EdgeInsetsGeometry? contentPadding,
  }) : super(
    builder: (FormFieldState<String> field) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: maxLines,
              minLines: minLines,
              textInputAction: textInputAction,
              enabled: enabled,
              autofocus: autofocus,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: contentPadding ??
                    const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                prefixIcon: prefixIcon,
                suffixIcon: suffixIcon,
              ),
              onSubmitted: onSubmitted,
              onChanged: (value) {
                field.didChange(value);
                onChanged?.call(value);
              },
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                field.errorText ?? '',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// A reusable rounded text field with consistent styling across the app.
class RoundedTextField extends StatelessWidget {
  const RoundedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Ask Anything',
    this.maxLines,
    this.minLines,
    this.maxHeight = 100,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
    this.borderRadius = 55,
    this.backgroundColor,
    this.contentPadding,
  });

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Focus node for the text field.
  final FocusNode? focusNode;

  /// Hint text displayed when the field is empty.
  final String hintText;

  /// Maximum number of lines (null for unlimited).
  final int? maxLines;

  /// Minimum number of lines.
  final int? minLines;

  /// Maximum height constraint for the text field container.
  final double maxHeight;

  /// Text input action for the keyboard.
  final TextInputAction? textInputAction;

  /// Callback when the user submits (presses done/enter).
  final ValueChanged<String>? onSubmitted;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  /// Whether the text field is enabled.
  final bool enabled;

  /// Whether to autofocus on mount.
  final bool autofocus;

  /// Optional prefix icon.
  final Widget? prefixIcon;

  /// Optional suffix icon.
  final Widget? suffixIcon;

  /// Border radius for the text field container.
  final double borderRadius;

  /// Background color (defaults to surfaceElevated).
  final Color? backgroundColor;

  /// Content padding inside the text field.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        minLines: minLines,
        textInputAction: textInputAction,
        enabled: enabled,
        autofocus: autofocus,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
        onSubmitted: onSubmitted,
        onChanged: onChanged,
      ),
    );
  }
}
