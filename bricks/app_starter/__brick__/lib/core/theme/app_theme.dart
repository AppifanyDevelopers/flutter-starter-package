import 'package:flutter/material.dart';

import '../../gen/colors.gen.dart';

abstract class AppTheme {
  AppTheme._();

  static ThemeData light(Color seed) => _build(seed, Brightness.light);

  static ThemeData dark(Color seed) => _build(seed, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    // Text, hints and borders come from the neutral ramp rather than the
    // seed-tinted Material defaults, so they stay the same across brand colours.
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      onSurface: isLight ? ColorName.neutral900 : ColorName.neutral50,
      onSurfaceVariant: isLight ? ColorName.neutral600 : ColorName.neutral300,
      outline: isLight ? ColorName.neutral500 : ColorName.neutral600,
      outlineVariant: isLight ? ColorName.neutral200 : ColorName.neutral900,
    );
    return ThemeData(
      useMaterial3: true,
      // app_starter:font
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionHandleColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.3),
      ),
      dividerColor: colorScheme.outlineVariant,
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: ColorName.neutral500),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
