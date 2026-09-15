import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application colors from brand guidelines.
abstract class AppColors {
  // Primary (Teal)
  static const primary = Color(0xFF14b8a6);
  static const primaryDark = Color(0xFF0d9488);
  static const primaryLight = Color(0xFF2dd4bf);

  // Secondary (Purple)
  static const secondary = Color(0xFF7c3aed);
  static const secondaryDark = Color(0xFF6d28d9);
  static const secondaryLight = Color(0xFF8b5cf6);

  // Accent (Pink)
  static const accent = Color(0xFFec4899);
  static const accentDark = Color(0xFFdb2777);
  static const accentLight = Color(0xFFf472b6);

  // Background
  static const background = Color(0xFF09090b);
  static const surface = Color(0xFF18181b);
  static const surfaceElevated = Color(0xFF27272a);

  // Border
  static const border = Color(0xFF3f3f46);
  static const borderLight = Color(0xFF52525b);

  // Text
  static const textPrimary = Color(0xFFfafafa);
  static const textSecondary = Color(0xFFa1a1aa);
  static const textMuted = Color(0xFF71717a);
  static const textInverse = Color(0xFF09090b);

  // Semantic
  static const success = Color(0xFF22c55e);
  static const warning = Color(0xFFf59e0b);
  static const error = Color(0xFFef4444);
  static const info = Color(0xFF3b82f6);
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
        onSecondary: AppColors.textPrimary,
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
