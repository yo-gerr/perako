import 'package:flutter/material.dart';

/// How the app picks its light/dark appearance.
enum ThemePreference {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemePreference(this.label);

  final String label;

  ThemeMode get themeMode => switch (this) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };
}

/// Device-level settings persisted in shared_preferences.
class AppSettings {
  const AppSettings({
    required this.themePreference,
    required this.currencyCode,
  });

  final ThemePreference themePreference;
  final String currencyCode;

  static const defaults = AppSettings(
    themePreference: ThemePreference.system,
    currencyCode: 'PHP',
  );

  AppSettings copyWith({ThemePreference? themePreference, String? currencyCode}) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themePreference == themePreference &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(themePreference, currencyCode);
}
