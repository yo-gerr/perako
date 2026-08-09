import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/core/router/app_router.dart';
import 'package:perako/features/auth/presentation/providers/auth_providers.dart';
import 'package:perako/features/sync/data/accounts_sync_table.dart';
import 'package:perako/features/sync/domain/sync_engine.dart';
import 'package:perako/features/sync/presentation/providers/sync_providers.dart';
import 'package:perako/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_sync_remote_store.dart';

void main() {
  late AppDatabase db;
  late FakeAuthRepository fakeAuth;
  late FakeSyncRemoteStore remoteStore;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeAuth = FakeAuthRepository();
    remoteStore = FakeSyncRemoteStore();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(fakeAuth),
      syncEngineProvider.overrideWithValue(
        SyncEngine(
          db: db,
          store: remoteStore,
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

  /// Pumps the real router in isolation.
  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pumps the full app (PerakoApp), which wires the sync-on-sign-in listener.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PerakoApp(),
      ),
    );
    await tester.pump();
  }

  Future<void> insertAccount(String id) async {
    await db.into(db.accounts).insert(AccountsCompanion(
          id: Value(id),
          name: Value('Checking'),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('teal'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(0),
          updatedAt: Value(1),
          version: const Value(1),
        ));
  }

  /// Pumps until [finder] matches, without settling on infinite spinners.
  Future<void> pumpUntilFound(
      WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for $finder');
  }

  /// Pumps until [condition] is true (for async work not tied to frames).
  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 50; i++) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Timed out waiting for condition');
  }

  testWidgets('opens straight to the dashboard without an account',
      (tester) async {
    await pumpRouter(tester);
    await pumpUntilFound(tester, find.text('Net Worth'));

    // No forced login and no splash gate: the shell is the home screen.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a signed-out restore lands on the dashboard, not login',
      (tester) async {
    await pumpRouter(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // Auth resolves to "no session" and the app stays put on the dashboard.
    fakeAuth.signOutUser();
    await pumpUntilFound(tester, find.text('Net Worth'));

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
    expect(find.text('Net Worth'), findsOneWidget);
  });

  testWidgets('a restored session lands on the dashboard without a login flash',
      (tester) async {
    await pumpRouter(tester);

    fakeAuth.signIn('uid_test');
    await pumpUntilFound(tester, find.text('Net Worth'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Net Worth'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });

  testWidgets('signing in mid-session pushes local data to the cloud',
      (tester) async {
    await insertAccount('a1');
    await pumpApp(tester);
    await pumpUntilFound(tester, find.text('Net Worth'));

    // Local-only usage first: nothing in the cloud for this uid yet.
    expect(remoteStore.store['uid_test'], isNull);

    fakeAuth.signIn('uid_test');
    await pumpUntil(
        tester, () => remoteStore.store['uid_test']?['accounts']?.isNotEmpty ?? false);

    expect(
        remoteStore.store['uid_test']!['accounts']!['a1'], isNotNull);
    expect(find.text('Net Worth'), findsOneWidget);
  });
}
