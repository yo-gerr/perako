import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/database_wipe_service.dart';
import 'package:perako/core/database/daos/goals_dao.dart';

void main() {
  late AppDatabase db;
  late GoalsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = GoalsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Goal> insertGoal({
    String id = 'g1',
    String name = 'Emergency fund',
    String type = 'savings',
    int targetAmountCents = 100000,
    int currentAmountCents = 0,
    int? targetDate,
  }) {
    return dao.insert(GoalsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      targetAmountCents: Value(targetAmountCents),
      currentAmountCents: Value(currentAmountCents),
      targetDate: Value(targetDate),
      fundingAccountId: const Value('dst'),
      isCompleted: const Value(false),
      createdAt: const Value(1),
      updatedAt: const Value(1),
      version: const Value(1),
    ));
  }

  test('insert is visible to active, watchActive, and allIncludingArchived',
      () async {
    await insertGoal();
    expect(await dao.active(), hasLength(1));
    expect(await dao.watchActive().first, hasLength(1));
    expect(await dao.allIncludingArchived(), hasLength(1));
  });

  test('updateGoal updates fields in place', () async {
    final goal = await insertGoal();
    await dao.updateGoal(GoalsCompanion(
      id: Value(goal.id),
      currentAmountCents: const Value(25000),
      updatedAt: const Value(2),
    ));

    final updated = await dao.byId(goal.id);
    expect(updated!.currentAmountCents, 25000);
    expect(updated.name, 'Emergency fund');
  });

  test('archive hides and reopen restores the goal', () async {
    final goal = await insertGoal();
    await dao.archive(goal.id, nowMillis: 99);

    expect(await dao.active(), isEmpty);
    expect(await dao.watchArchived().first, hasLength(1));

    await dao.reopen(goal.id, nowMillis: 100);
    expect(await dao.active(), hasLength(1));
    expect(await dao.watchArchived().first, isEmpty);

    final restored = await dao.byId(goal.id);
    expect(restored!.deletedAt, isNull);
  });

  test('contributions are inserted and listed per goal', () async {
    final goal = await insertGoal();
    await dao.insertContribution(GoalContributionsCompanion(
      id: const Value('c1'),
      goalId: Value(goal.id),
      transactionId: const Value('t1'),
      amountCents: const Value(5000),
      contributedOn: const Value(10),
      note: const Value(null),
      createdAt: const Value(10),
    ));
    await dao.insertContribution(GoalContributionsCompanion(
      id: const Value('c2'),
      goalId: Value(goal.id),
      transactionId: const Value('t2'),
      amountCents: const Value(15000),
      contributedOn: const Value(20),
      note: const Value('Paycheck'),
      createdAt: const Value(20),
    ));

    expect(await dao.watchContributionsFor(goal.id).first, hasLength(2));
    final rows = await dao.contributionsFor(goal.id);
    expect(rows.map((c) => c.amountCents), containsAll([5000, 15000]));
  });

  test('changedSince returns only rows updated at or after the cursor',
      () async {
    await insertGoal(id: 'g1', name: 'Old');
    await db.into(db.goals).insert(GoalsCompanion(
          id: const Value('g2'),
          name: const Value('New'),
          type: const Value('savings'),
          targetAmountCents: const Value(100000),
          fundingAccountId: const Value('dst'),
          createdAt: const Value(50),
          updatedAt: const Value(50),
          version: const Value(1),
        ));

    final since = await dao.changedSince(50);
    expect(since.map((g) => g.id), ['g2']);
  });

  test('wipeAll clears goals and their contributions', () async {
    final goal = await insertGoal();
    await dao.insertContribution(GoalContributionsCompanion(
      id: const Value('c1'),
      goalId: Value(goal.id),
      transactionId: const Value('t1'),
      amountCents: const Value(5000),
      contributedOn: const Value(10),
      note: const Value(null),
      createdAt: const Value(10),
    ));

    await DatabaseWipeService(db).wipeAll();

    expect(await db.select(db.goals).get(), isEmpty);
    expect(await db.select(db.goalContributions).get(), isEmpty);
  });
}
