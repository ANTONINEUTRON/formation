import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application colors. A floodlit night pitch with a lime accent, kept in step
/// with the landing page (landing_page/index.html, `:root`).
abstract class AppColors {
  // Primary (Lime)
  static const primary = Color(0xFFB8FF3C);
  static const primaryDark = Color(0xFF8FD617);
  static const primaryLight = Color(0xFFD4FF85);

  // Secondary (deep lime)
  static const secondary = Color(0xFF8FD617);

  // Risk tiers. Their own tokens, not aliases of the brand colours, so
  // re-theming the app can never change what a tier looks like.
  static const tierBlueChip = Color(0xFF7FD8FF);
  static const tierStable = Color(0xFF9DB3A5);
  static const tierBalanced = Color(0xFFC9B4FF);
  static const tierGrowth = Color(0xFFB8FF3C);
  static const tierMomentum = Color(0xFFFFB43C);

  // Background (night pitch)
  static const background = Color(0xFF0A1410);
  static const surface = Color(0xFF0F1F18);
  static const surfaceElevated = Color(0xFF123122);

  // Border
  static const border = Color(0xFF24503A);
  static const borderLight = Color(0xFF2F6048);

  // Text (chalk)
  static const textPrimary = Color(0xFFEDF2EC);
  static const textSecondary = Color(0xFF9DB3A5);
  static const textMuted = Color(0xFF6B8577);
  static const textInverse = Color(0xFF0A1410);

  // Semantic
  static const success = Color(0xFFB8FF3C);
  static const warning = Color(0xFFFFB43C);
  static const error = Color(0xFFFF5C5C);
  static const info = Color(0xFF7FD8FF);
}

/// Application theme configuration.
class AppTheme {
  AppTheme._();

  /// Dark theme (primary theme)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.textInverse,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textInverse,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
      ),
    );
  }

  /// Light theme (optional)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      textTheme: GoogleFonts.soraTextTheme(),
    );
  }

  /// Primary theme (dark by default per brand guidelines)
  static ThemeData get primaryTheme => darkTheme;
}

/// Shared text styles for numeric and technical surfaces.
/// Use these wherever financial values, wallet addresses, tx hashes, or
/// percentages are displayed.
abstract class AppTextStyles {
  /// JetBrains Mono — for prices, PnL, wallet addresses, tx IDs, percentages.
  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
}
