import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perako/features/settings/domain/app_settings.dart';
import 'package:perako/features/settings/presentation/providers/settings_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('settingsProvider loads defaults on startup', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);
    expect(settings, AppSettings.defaults);
  });

  test('setThemePreference updates state and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);

    await container
        .read(settingsProvider.notifier)
        .setThemePreference(ThemePreference.dark);

    expect(
      container.read(settingsProvider).valueOrNull?.themePreference,
      ThemePreference.dark,
    );
    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.themePreference'), 'dark');
  });

  test('setCurrencyCode updates the formatting symbol', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setCurrencyCode('USD');

    expect(container.read(settingsProvider).valueOrNull?.currencyCode, 'USD');
    expect(container.read(currencySymbolProvider), r'$');
  });

  test('settings survive a container rebuild (persistence)', () async {
    var container = ProviderContainer();
    await container.read(settingsProvider.future);
    await container
        .read(settingsProvider.notifier)
        .setCurrencyCode('EUR');
    container.dispose();

    container = ProviderContainer();
    addTearDown(container.dispose);
    final settings = await container.read(settingsProvider.future);
    expect(settings.currencyCode, 'EUR');
  });
}
