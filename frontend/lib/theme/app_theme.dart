import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF168653);
  static const _runnerAccent = Color(0xFFD7F36A);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF147A4B),
      onPrimary: Colors.white,
      secondary: const Color(0xFF4B6B24),
      onSecondary: Colors.white,
      tertiary: const Color(0xFFDAF27B),
      surface: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF1F5EF),
      surfaceContainer: const Color(0xFFE9EFE8),
      outline: const Color(0xFF7B897E),
      outlineVariant: const Color(0xFFDCE4DC),
    );

    return _build(colorScheme, const Color(0xFFF4F7F2));
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF8FE0A8),
      onPrimary: const Color(0xFF092114),
      secondary: _runnerAccent,
      onSecondary: const Color(0xFF26320B),
      tertiary: const Color(0xFFB9E77B),
      surface: const Color(0xFF171D19),
      surfaceContainerLowest: const Color(0xFF101512),
      surfaceContainerLow: const Color(0xFF1D2520),
      surfaceContainer: const Color(0xFF242D27),
      outline: const Color(0xFF89968C),
      outlineVariant: const Color(0xFF3A473E),
    );

    return _build(colorScheme, const Color(0xFF101512));
  }

  static ThemeData _build(ColorScheme colorScheme, Color background) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor:
            isDark ? colorScheme.surfaceContainer : colorScheme.surface,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
      ),
    );
  }
}
