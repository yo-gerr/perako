import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perako/features/settings/domain/app_settings.dart';
import 'package:perako/features/settings/domain/currencies.dart';
import 'package:perako/features/settings/domain/settings_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsSettingsRepository', () {
    test('loads defaults when nothing is stored', () async {
      final repo = SharedPrefsSettingsRepository();
      final settings = await repo.load();
      expect(settings.themePreference, ThemePreference.system);
      expect(settings.currencyCode, 'PHP');
    });

    test('round-trips theme and currency', () async {
      final repo = SharedPrefsSettingsRepository();
      await repo.setThemePreference(ThemePreference.light);
      await repo.setCurrencyCode('EUR');

      final settings = await repo.load();
      expect(settings.themePreference, ThemePreference.light);
      expect(settings.currencyCode, 'EUR');
    });

    test('persists to the shared_preferences store', () async {
      final repo = SharedPrefsSettingsRepository();
      await repo.setThemePreference(ThemePreference.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.themePreference'), 'dark');
    });
  });

  group('currency helpers', () {
    test('maps known codes to symbols', () {
      expect(currencySymbol('PHP'), '₱');
      expect(currencySymbol('USD'), r'$');
      expect(currencySymbol('EUR'), '€');
    });

    test('falls back to the code for unknown currencies', () {
      expect(currencySymbol('XYZ'), 'XYZ ');
      expect(currencyName('XYZ'), 'XYZ');
    });
  });
}
