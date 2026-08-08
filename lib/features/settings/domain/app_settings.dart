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
    required this.sidebarCollapsed,
  });

  final ThemePreference themePreference;
  final String currencyCode;

  /// Whether the wide-surface sidebar is collapsed to the icon rail.
  final bool sidebarCollapsed;

  static const defaults = AppSettings(
    themePreference: ThemePreference.system,
    currencyCode: 'PHP',
    sidebarCollapsed: false,
  );

  AppSettings copyWith({
    ThemePreference? themePreference,
    String? currencyCode,
    bool? sidebarCollapsed,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      currencyCode: currencyCode ?? this.currencyCode,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themePreference == themePreference &&
      other.currencyCode == currencyCode &&
      other.sidebarCollapsed == sidebarCollapsed;

  @override
  int get hashCode => Object.hash(themePreference, currencyCode, sidebarCollapsed);
}
