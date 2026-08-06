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

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_sync_remote_store.dart';

/// Pumps until [finder] matches, without settling on the infinite splash
/// spinner. Fails if the widget does not appear in time.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for $finder');
}

void main() {
  testWidgets('shell lands on dashboard and navigates tabs and drawer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final fakeAuth = FakeAuthRepository();
    final container = ProviderContainer(overrides: [
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
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pump();

    // Sign in to pass the auth redirect. The splash screen animates forever,
    // so settle on the dashboard with bounded pumps rather than
    // pumpAndSettle.
    fakeAuth.signIn('uid_test');
    await pumpUntilFound(tester, find.text('Net Worth'));
    // Let the splash-to-dashboard route transition finish.
    await tester.pump(const Duration(milliseconds: 400));

    // Dashboard is the initial tab.
    expect(find.text('PeraKo'), findsOneWidget);
    expect(find.text('Net Worth'), findsOneWidget);

    // Switch to the Accounts tab.
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Accounts'),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Accounts'), findsOneWidget);

    // Switch to the Transactions tab.
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Transactions'),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Transactions'), findsOneWidget);

    // Open the drawer and go to Categories.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Categories'), findsOneWidget);
  });
}
