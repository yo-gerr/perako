import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/auth/database_sync_coordinator.dart';
import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/auth/presentation/providers/auth_providers.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  late FakeAuthRepository auth;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = FakeAuthRepository();

    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((_) => db),
      authRepositoryProvider.overrideWithValue(auth),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('DatabaseWipeService clears all ledger rows and cursors', () async {
    await db.into(db.accounts).insert(AccountsCompanion(
          id: Value('a1'),
          name: const Value('Checking'),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('teal'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(0),
          updatedAt: Value(1),
          version: const Value(1),
        ));

    expect(await db.select(db.accounts).get(), hasLength(1));

    await container.read(databaseWipeServiceProvider).wipeAll();
    expect(await db.select(db.accounts).get(), isEmpty);
  });

  test('wipe clears sync cursors so next user pulls fresh', () async {
    await db.into(db.syncState).insert(SyncStateCompanion.insert(
          collection: 'accounts',
          lastSyncedAt: Value(99),
        ));

    await container.read(databaseWipeServiceProvider).wipeAll();
    expect(await db.select(db.syncState).get(), isEmpty);
  });

  testWidgets('coordinator wipes local data when the user changes',
      (tester) async {
    await db.into(db.accounts).insert(AccountsCompanion(
          id: Value('a1'),
          name: const Value('Checking'),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('teal'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(0),
          updatedAt: Value(1),
          version: const Value(1),
        ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: DatabaseWipeCoordinator(
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    ));
    await tester.pump();

    // Sign in as a user, then switch to another — first emission is recorded,
    // the change triggers a wipe.
    auth.signIn('uid_one');
    await tester.pump();
    expect(await db.select(db.accounts).get(), hasLength(1));

    auth.signOutUser();
    await tester.pump();
    await tester.pump();
    expect(await db.select(db.accounts).get(), isEmpty);
  });
}