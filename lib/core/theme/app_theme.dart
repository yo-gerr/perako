import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized [ThemeData] for PeraKo.
abstract final class AppTheme {
  /// Primary typeface: a friendly, rounded geometric sans with tabular
  /// figures, so money figures align cleanly in lists and charts.
  static const String fontFamily = 'Manrope';

  /// Fallback family for any glyph Manrope does not ship.
  static const List<String> fontFamilyFallback = ['Roboto'];

  /// Fixed-width digits keep amounts lined up in columns.
  static const List<FontFeature> fontFeatures = [
    FontFeature.tabularFigures(),
  ];

  static ThemeData light() => _theme(_lightScheme());

  static ThemeData dark() => _theme(_darkScheme());

  static ThemeData _theme(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
    return base.copyWith(textTheme: _withTabularFigures(base.textTheme));
  }

  static TextTheme _withTabularFigures(TextTheme t) {
    TextStyle apply(TextStyle style) =>
        style.copyWith(fontFeatures: fontFeatures);
    return TextTheme(
      displayLarge: apply(t.displayLarge!),
      displayMedium: apply(t.displayMedium!),
      displaySmall: apply(t.displaySmall!),
      headlineLarge: apply(t.headlineLarge!),
      headlineMedium: apply(t.headlineMedium!),
      headlineSmall: apply(t.headlineSmall!),
      titleLarge: apply(t.titleLarge!),
      titleMedium: apply(t.titleMedium!),
      titleSmall: apply(t.titleSmall!),
      bodyLarge: apply(t.bodyLarge!),
      bodyMedium: apply(t.bodyMedium!),
      bodySmall: apply(t.bodySmall!),
      labelLarge: apply(t.labelLarge!),
      labelMedium: apply(t.labelMedium!),
      labelSmall: apply(t.labelSmall!),
    );
  }

  /// Tints [color] over [base] to build a soft container color.
  static Color _tint(Color color, double alpha, Color base) =>
      Color.alphaBlend(color.withValues(alpha: alpha), base);

  static ColorScheme _lightScheme() => ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: _tint(AppColors.secondary, 0.14, AppColors.lightSurface),
        onSecondaryContainer: AppColors.lightTextPrimary,
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: _tint(AppColors.accent, 0.14, AppColors.lightSurface),
        onTertiaryContainer: AppColors.lightTextPrimary,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: _tint(AppColors.error, 0.12, AppColors.lightSurface),
        onErrorContainer: AppColors.error,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightDivider,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.darkSurface,
        onInverseSurface: AppColors.darkTextPrimary,
        inversePrimary: AppColors.primaryDark,
        surfaceTint: AppColors.primary,
        surfaceContainerLowest: AppColors.lightSurface,
        surfaceContainerLow: AppColors.lightSurfaceVariant,
        surfaceContainer: AppColors.lightBackground,
        surfaceContainerHigh: AppColors.lightDivider,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
      );

  static ColorScheme _darkScheme() => ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        onPrimary: AppColors.darkBackground,
        primaryContainer: AppColors.primaryDarkContainer,
        onPrimaryContainer: AppColors.darkTextPrimary,
        secondary: AppColors.secondaryDark,
        onSecondary: AppColors.darkBackground,
        secondaryContainer: _tint(AppColors.secondaryDark, 0.16, AppColors.darkSurface),
        onSecondaryContainer: AppColors.darkTextPrimary,
        tertiary: AppColors.accentDark,
        onTertiary: AppColors.darkBackground,
        tertiaryContainer: _tint(AppColors.accentDark, 0.16, AppColors.darkSurface),
        onTertiaryContainer: AppColors.darkTextPrimary,
        error: AppColors.errorDark,
        onError: AppColors.darkBackground,
        errorContainer: _tint(AppColors.errorDark, 0.18, AppColors.darkSurface),
        onErrorContainer: AppColors.errorDark,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkDivider,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.lightSurface,
        onInverseSurface: AppColors.lightTextPrimary,
        inversePrimary: AppColors.primary,
        surfaceTint: AppColors.primaryDark,
        surfaceContainerLowest: AppColors.darkBackground,
        surfaceContainerLow: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurface,
        surfaceContainerHigh: AppColors.darkSurfaceElevated,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
      );
}
