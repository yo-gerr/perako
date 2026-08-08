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

import 'fake_auth_repository.dart';
import 'fake_sync_remote_store.dart';

/// Pumps until [finder] matches, without settling on the infinite splash
/// spinner. Fails if the widget does not appear in time.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for $finder');
}

class SignedInShellHarness {
  const SignedInShellHarness({required this.container, required this.auth});

  final ProviderContainer container;
  final FakeAuthRepository auth;
}

/// Boots the app through the real router on a [size] surface, signs in, and
/// settles on the dashboard. The container and database are disposed by the
/// test framework.
Future<SignedInShellHarness> pumpSignedInShell(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
  Map<String, Object> initialPrefs = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(initialPrefs);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  final auth = FakeAuthRepository();
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(auth),
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

  auth.signIn('uid_test');
  await pumpUntilFound(tester, find.text('Net Worth'));
  // Let the splash-to-dashboard route transition finish.
  await tester.pump(const Duration(milliseconds: 400));
  return SignedInShellHarness(container: container, auth: auth);
}

/// Resizes the test surface to [size] and rebuilds.
Future<void> resizeSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pump();
}
