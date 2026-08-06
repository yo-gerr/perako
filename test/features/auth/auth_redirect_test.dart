import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/core/router/app_router.dart';
import 'package:perako/core/widgets/splash_screen.dart';
import 'package:perako/features/auth/presentation/providers/auth_providers.dart';
import 'package:perako/features/sync/data/accounts_sync_table.dart';
import 'package:perako/features/sync/domain/sync_engine.dart';
import 'package:perako/features/sync/presentation/providers/sync_providers.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_sync_remote_store.dart';

void main() {
  late AppDatabase db;
  late FakeAuthRepository fakeAuth;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeAuth = FakeAuthRepository();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(fakeAuth),
      syncEngineProvider.overrideWithValue(
        SyncEngine(
          db: db,
          store: FakeSyncRemoteStore(),
          deviceId: 'device_test',
          tables: [AccountsSyncTable(db: db)],
        ),
      ),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    // Let the router run its (async) initial redirect while auth is pending.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Pumps until [finder] matches, without settling on the infinite splash
  /// spinner. Fails if the widget does not appear in time.
  Future<void> pumpUntilFound(
      WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for $finder');
  }

  testWidgets(
      'parks on splash while auth state is loading, never showing login',
      (tester) async {
    await pumpApp(tester);

    // No auth emission yet: the redirect must hold on the splash screen
    // instead of flashing the login page.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('restored session lands on the dashboard without a login flash',
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    // Simulate Firebase restoring the persisted session after refresh.
    fakeAuth.signIn('uid_test');
    await pumpUntilFound(tester, find.text('Net Worth'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Net Worth'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('signed-out restore routes to the login screen', (tester) async {
    await pumpApp(tester);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Simulate Firebase resolving with no session.
    fakeAuth.signOutUser();
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
