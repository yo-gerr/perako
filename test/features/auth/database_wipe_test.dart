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

  test('wipe clears profiles', () async {
    await db.into(db.profiles).insert(ProfilesCompanion(
          uid: const Value('u1'),
          displayName: const Value('Rey'),
          currency: const Value('PHP'),
          createdAt: Value(1),
          updatedAt: Value(1),
        ));

    await container.read(databaseWipeServiceProvider).wipeAll();
    expect(await db.select(db.profiles).get(), isEmpty);
  });

  test('wipe clears budgets and their category limits', () async {
    await db.into(db.budgets).insert(BudgetsCompanion(
          id: const Value('b1'),
          name: const Value('Groceries'),
          amountCents: const Value(50000),
          period: const Value('monthly'),
          categoryId: const Value(null),
          accountId: const Value(null),
          rollover: const Value(false),
          createdAt: Value(1),
          updatedAt: Value(1),
        ));
    await db.into(db.categoryBudgetLimits).insert(
          CategoryBudgetLimitsCompanion(
            id: const Value('l1'),
            budgetId: const Value('b1'),
            categoryId: const Value('c1'),
            amountCents: const Value(20000),
            updatedAt: const Value(1),
          ),
        );

    await container.read(databaseWipeServiceProvider).wipeAll();
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.categoryBudgetLimits).get(), isEmpty);
  });

  test('wipe clears bills and their payments', () async {
    await db.into(db.bills).insert(BillsCompanion(
          id: const Value('b1'),
          name: const Value('Rent'),
          accountId: const Value('a1'),
          categoryId: const Value(null),
          amountCents: const Value(150000),
          frequency: const Value('monthly'),
          dayOfMonth: const Value(1),
          nextDueDate: Value(1),
          createdAt: Value(1),
          updatedAt: Value(1),
        ));
    await db.into(db.billPayments).insert(BillPaymentsCompanion(
          id: const Value('p1'),
          billId: const Value('b1'),
          transactionId: const Value('t1'),
          amountCents: const Value(150000),
          paidOn: Value(1),
          note: const Value(null),
          createdAt: Value(1),
        ));

    await container.read(databaseWipeServiceProvider).wipeAll();
    expect(await db.select(db.bills).get(), isEmpty);
    expect(await db.select(db.billPayments).get(), isEmpty);
  });

  test('wipe clears goals and their contributions', () async {
    await db.into(db.goals).insert(GoalsCompanion(
          id: const Value('g1'),
          name: const Value('Emergency fund'),
          type: const Value('savings'),
          targetAmountCents: const Value(100000),
          currentAmountCents: const Value(25000),
          fundingAccountId: const Value('a1'),
          isCompleted: const Value(false),
          createdAt: Value(1),
          updatedAt: Value(1),
        ));
    await db.into(db.goalContributions).insert(GoalContributionsCompanion(
          id: const Value('c1'),
          goalId: const Value('g1'),
          transactionId: const Value('t1'),
          amountCents: const Value(25000),
          contributedOn: Value(1),
          note: const Value(null),
          createdAt: Value(1),
        ));

    await container.read(databaseWipeServiceProvider).wipeAll();
    expect(await db.select(db.goals).get(), isEmpty);
    expect(await db.select(db.goalContributions).get(), isEmpty);
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