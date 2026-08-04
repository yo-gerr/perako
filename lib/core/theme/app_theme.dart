import 'package:flutter/material.dart';

/// Centralized [ThemeData] for PeraKo.
abstract final class AppTheme {
  static ThemeData light() =>
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal));

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      );
}
