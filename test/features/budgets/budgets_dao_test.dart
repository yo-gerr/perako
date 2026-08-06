import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/budgets_dao.dart';
import 'package:perako/core/database/daos/database_wipe_service.dart';

void main() {
  late AppDatabase db;
  late BudgetsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = BudgetsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  BudgetsCompanion companion({
    String? id,
    String name = 'Groceries',
    int amountCents = 50000,
    String period = 'monthly',
    String? categoryId,
    String? accountId,
    bool rollover = false,
  }) {
    return BudgetsCompanion(
      id: Value(id ?? 'bgt_$name'),
      name: Value(name),
      amountCents: Value(amountCents),
      period: Value(period),
      categoryId: Value(categoryId),
      accountId: Value(accountId),
      rollover: Value(rollover),
      createdAt: const Value(1),
      updatedAt: const Value(1),
      version: const Value(1),
    );
  }

  test('insert returns a row visible to active()', () async {
    final row = await dao.insert(companion(name: 'Food'));
    expect(row.name, 'Food');
    expect(await dao.active(), hasLength(1));
    expect(await dao.watchActive().first, hasLength(1));
    expect(await dao.allIncludingArchived(), hasLength(1));
  });

  test('updateBudget modifies fields in place', () async {
    final row = await dao.insert(companion());
    await dao.updateBudget(BudgetsCompanion(
      id: Value(row.id),
      name: const Value('Rent'),
      amountCents: const Value(150000),
      period: const Value('monthly'),
      categoryId: const Value('housing'),
      accountId: const Value(null),
      rollover: const Value(false),
      updatedAt: const Value(2),
    ));

    final updated = await dao.byId(row.id);
    expect(updated!.name, 'Rent');
    expect(updated.amountCents, 150000);
    expect(updated.categoryId, 'housing');
  });

  test('archive hides the row from active and reopen restores it', () async {
    final row = await dao.insert(companion());
    await dao.archive(row.id, nowMillis: 10);

    expect(await dao.active(), isEmpty);
    final archived = await dao.watchArchived().first;
    expect(archived, hasLength(1));
    expect(archived.single.deletedAt, 10);

    await dao.reopen(row.id, nowMillis: 11);
    expect(await dao.active(), hasLength(1));
    expect(await dao.watchArchived().first, isEmpty);
  });

  test('replaceLimits replaces all limit rows for the budget', () async {
    final row = await dao.insert(companion());
    await db.into(db.categories).insert(CategoriesCompanion(
          id: const Value('c1'),
          name: const Value('Food'),
          type: const Value('expense'),
          color: const Value('red'),
          icon: const Value('restaurant'),
          updatedAt: const Value(1),
        ));

    await dao.replaceLimits(row.id, [
      CategoryBudgetLimitsCompanion(
        id: const Value('l1'),
        budgetId: Value(row.id),
        categoryId: const Value('c1'),
        amountCents: const Value(20000),
        updatedAt: const Value(1),
      ),
    ]);
    expect(await dao.limitsFor(row.id), hasLength(1));

    // Replacing clears the previous rows.
    await dao.replaceLimits(row.id, []);
    expect(await dao.limitsFor(row.id), isEmpty);

    await dao.replaceLimits(row.id, [
      CategoryBudgetLimitsCompanion(
        id: const Value('l2'),
        budgetId: Value(row.id),
        categoryId: const Value('c1'),
        amountCents: const Value(30000),
        updatedAt: const Value(2),
      ),
    ]);
    final limits = await dao.limitsFor(row.id);
    expect(limits, hasLength(1));
    expect(limits.single.amountCents, 30000);
  });

  test('changedSince returns rows updated at or after the cursor', () async {
    final a = await dao.insert(companion(name: 'A'));
    final b = await dao.insert(companion(name: 'B'));
    await dao.archive(b.id, nowMillis: 20);

    final changed = await dao.changedSince(20);
    expect(changed.map((e) => e.id), [b.id]);

    final all = await dao.changedSince(0);
    expect(all.map((e) => e.id).toSet(), containsAll([a.id, b.id]));
  });

  test('wipeAll removes budgets and their category limits', () async {
    final row = await dao.insert(companion());
    await dao.replaceLimits(row.id, [
      CategoryBudgetLimitsCompanion(
        id: const Value('l1'),
        budgetId: Value(row.id),
        categoryId: const Value('c1'),
        amountCents: const Value(20000),
        updatedAt: const Value(1),
      ),
    ]);

    await DatabaseWipeService(db).wipeAll();
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.categoryBudgetLimits).get(), isEmpty);
  });
}
