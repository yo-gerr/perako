import 'package:flutter/material.dart';

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

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      ),
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
}
