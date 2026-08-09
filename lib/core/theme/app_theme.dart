import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'perako_colors.dart';

/// Centralized [ThemeData] for PeraKo, following the Perako Design System.
///
/// Design philosophy:
/// - Neutral backgrounds, white (light) / elevated-dark surfaces.
/// - Blue stays the primary brand color for actions and navigation.
/// - Green communicates income/growth, gold communicates attention/goals,
///   magenta communicates investments/special events, lime communicates
///   achievements, and red is reserved for actual problems.
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

  static ThemeData light() => _theme(_lightScheme(), PerakoColors.light);

  static ThemeData dark() => _theme(_darkScheme(), PerakoColors.dark);

  static ThemeData _theme(ColorScheme scheme, PerakoColors perako) {
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      extensions: [perako],
    );

    final light = scheme.brightness == Brightness.light;
    final background = light ? AppColors.lightBackground : AppColors.darkBackground;
    final surface = light ? AppColors.lightSurface : AppColors.darkSurface;
    final border = light ? AppColors.lightBorder : AppColors.darkBorder;

    final textTheme = _withTabularFigures(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      dividerColor: light ? AppColors.lightDivider : AppColors.darkDivider,
      textTheme: _withDesignTextColors(
        textTheme,
        primary: scheme.onSurface,
        secondary: scheme.onSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            light ? AppColors.lightTextPrimary : AppColors.darkSurfaceElevated,
        contentTextStyle: TextStyle(
          color: light ? Colors.white : AppColors.darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  /// Applies the design's semantic text colors: primary text for headings and
  /// body, secondary for supporting text and labels.
  static TextTheme _withDesignTextColors(
    TextTheme t, {
    required Color primary,
    required Color secondary,
  }) {
    TextStyle primaryFor(TextStyle style) => style.copyWith(color: primary);
    TextStyle secondaryFor(TextStyle style) => style.copyWith(color: secondary);
    return TextTheme(
      displayLarge: primaryFor(t.displayLarge!),
      displayMedium: primaryFor(t.displayMedium!),
      displaySmall: primaryFor(t.displaySmall!),
      headlineLarge: primaryFor(t.headlineLarge!),
      headlineMedium: primaryFor(t.headlineMedium!),
      headlineSmall: primaryFor(t.headlineSmall!),
      titleLarge: primaryFor(t.titleLarge!),
      titleMedium: primaryFor(t.titleMedium!),
      titleSmall: secondaryFor(t.titleSmall!),
      bodyLarge: primaryFor(t.bodyLarge!),
      bodyMedium: primaryFor(t.bodyMedium!),
      bodySmall: secondaryFor(t.bodySmall!),
      labelLarge: primaryFor(t.labelLarge!),
      labelMedium: secondaryFor(t.labelMedium!),
      labelSmall: secondaryFor(t.labelSmall!),
    );
  }

  static ColorScheme _lightScheme() => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: Color(0xFF00345C),
        secondary: AppColors.warning,
        onSecondary: Color(0xFF332300),
        secondaryContainer: AppColors.warningContainer,
        onSecondaryContainer: Color(0xFF5A4100),
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.accentContainer,
        onTertiaryContainer: Color(0xFF650035),
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        surfaceContainerLowest: AppColors.lightSurface,
        surfaceContainerLow: AppColors.lightSurfaceVariant,
        surfaceContainer: AppColors.lightBackground,
        surfaceContainerHigh: AppColors.lightDivider,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: Color(0xFF6B1B1B),
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightDivider,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.darkSurface,
        onInverseSurface: AppColors.darkTextPrimary,
        inversePrimary: AppColors.primaryDark,
        surfaceTint: AppColors.primary,
      );

  static ColorScheme _darkScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainerDark,
        onPrimaryContainer: Color(0xFFD7ECFF),
        secondary: AppColors.warning,
        onSecondary: Color(0xFF2E2100),
        secondaryContainer: AppColors.warningContainerDark,
        onSecondaryContainer: Color(0xFFFFE8A3),
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.accentContainerDark,
        onTertiaryContainer: Color(0xFFFFD9EA),
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        surfaceContainerLowest: AppColors.darkBackground,
        surfaceContainerLow: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurface,
        surfaceContainerHigh: AppColors.darkSurfaceElevated,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        error: AppColors.errorDark,
        onError: Colors.black,
        errorContainer: AppColors.errorContainerDark,
        onErrorContainer: Color(0xFFFFDADA),
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkDivider,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: AppColors.lightSurface,
        onInverseSurface: AppColors.lightTextPrimary,
        inversePrimary: AppColors.primary,
        surfaceTint: AppColors.primaryDark,
      );
}

