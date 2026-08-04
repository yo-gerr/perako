import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Persists device-level [AppSettings] to shared_preferences.
abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<void> setThemePreference(ThemePreference preference);

  Future<void> setCurrencyCode(String code);
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _themeKey = 'settings.themePreference';
  static const _currencyKey = 'settings.currencyCode';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefs;
    return AppSettings(
      themePreference: ThemePreference.values.firstWhere(
        (p) => p.name == prefs.getString(_themeKey),
        orElse: () => AppSettings.defaults.themePreference,
      ),
      currencyCode:
          prefs.getString(_currencyKey) ?? AppSettings.defaults.currencyCode,
    );
  }

  @override
  Future<void> setThemePreference(ThemePreference preference) async {
    (await _prefs).setString(_themeKey, preference.name);
  }

  @override
  Future<void> setCurrencyCode(String code) async {
    (await _prefs).setString(_currencyKey, code);
  }
}
