import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/app_settings.dart';
import '../../domain/currencies.dart';
import '../../domain/settings_repository.dart';

/// The settings repository. In tests, `SharedPreferences.setMockInitialValues`
/// makes the default implementation fully functional.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SharedPrefsSettingsRepository();
});

/// Device-level settings, loaded from shared_preferences on startup and
/// persisted on every change.
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsRepositoryProvider).load();

  Future<void> setThemePreference(ThemePreference preference) async {
    await ref.read(settingsRepositoryProvider).setThemePreference(preference);
    state = AsyncData((state.valueOrNull ?? AppSettings.defaults)
        .copyWith(themePreference: preference));
  }

  Future<void> setCurrencyCode(String code) async {
    await ref.read(settingsRepositoryProvider).setCurrencyCode(code);
    state = AsyncData(
        (state.valueOrNull ?? AppSettings.defaults).copyWith(currencyCode: code));
  }
}

/// The symbol used by `formatMoney`, following the selected currency.
final currencySymbolProvider = Provider<String>((ref) {
  final code =
      ref.watch(settingsProvider).valueOrNull?.currencyCode ?? 'PHP';
  return currencySymbol(code);
});

/// The [ThemeMode] for `MaterialApp`, following the theme preference.
final themeModeProvider = Provider<ThemeMode?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.themePreference.themeMode;
});

/// The current user's profile row, or null when absent / signed out.
final profileProvider = FutureProvider.family<Profile?, String>((ref, uid) {
  return ref.watch(profilesDaoProvider).byUid(uid);
});
