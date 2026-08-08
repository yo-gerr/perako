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
  testWidgets('wide surface shows a sidebar and no bottom navigation bar',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    fakeAuth.signIn('uid_test');
    await pumpUntilFound(tester, find.text('Net Worth'));
    await tester.pump(const Duration(milliseconds: 400));

    // The bottom navigation bar is replaced by the sidebar on wide surfaces.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);

    // Navigate through the sidebar.
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Categories'), findsOneWidget);

    // The sidebar stays visible and other destinations remain reachable.
    expect(find.text('Bonds'), findsOneWidget);
    await tester.tap(find.text('Bonds'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Bonds'), findsOneWidget);
  });
}
