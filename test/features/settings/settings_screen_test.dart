import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/core/theme/app_theme.dart';
import 'package:perako/features/auth/presentation/providers/auth_providers.dart';
import 'package:perako/features/settings/domain/app_settings.dart';
import 'package:perako/features/settings/presentation/providers/settings_providers.dart';
import 'package:perako/features/settings/presentation/screens/profile_screen.dart';
import 'package:perako/features/settings/presentation/screens/settings_screen.dart';

import '../../helpers/fake_auth_repository.dart';

/// Mirrors the wiring in `main.dart`: theme/themeMode come from providers.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider) ?? ThemeMode.system,
      home: const SettingsScreen(),
    );
  }
}

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('switching theme updates MaterialApp.themeMode', (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const _TestApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(
      container.read(settingsProvider).valueOrNull?.themePreference,
      ThemePreference.dark,
    );
  });

  testWidgets('changing the currency updates the formatting symbol',
      (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const _TestApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('USD — US Dollar').last);
    await tester.pumpAndSettle();

    expect(container.read(currencySymbolProvider), r'$');
    expect(
      container.read(settingsProvider).valueOrNull?.currencyCode,
      'USD',
    );
  });

  testWidgets('saving a profile upserts the Profiles row', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final containerWithDb = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(containerWithDb.dispose);

    final router = GoRouter(
      initialLocation: '/settings/profile',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'settings/profile',
                builder: (c, s) => const ProfileScreen()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: containerWithDb,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    auth.signIn('uid_test');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Rey');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.profiles).get();
    expect(rows, hasLength(1));
    expect(rows.single.displayName, 'Rey');
    expect(rows.single.currency, 'PHP');

    // Saved, then popped back to the home route.
    expect(find.text('home'), findsOneWidget);
  });
}
