import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Budgets] and [CategoryBudgetLimits]. All SQL for budgets
/// is scoped here.
class BudgetsDao extends DatabaseAccessor<AppDatabase> {
  BudgetsDao(super.db);

  $BudgetsTable get budgets => attachedDatabase.budgets;

  $CategoryBudgetLimitsTable get limits => attachedDatabase.categoryBudgetLimits;

  Future<Budget> insert(BudgetsCompanion entry) async {
    return into(budgets).insertReturning(entry);
  }

  Future<int> updateBudget(BudgetsCompanion entry) async {
    return (update(budgets)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<int> reopen(String id, {required int nowMillis}) {
    return (update(budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: const Value(null),
      ),
    );
  }

  Stream<List<Budget>> watchActive() =>
      (select(budgets)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<Budget>> active() =>
      (select(budgets)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<Budget>> watchArchived() =>
      (select(budgets)..where((t) => t.deletedAt.isNotNull())).watch();

  Future<List<Budget>> allIncludingArchived() => select(budgets).get();

  Future<Budget?> byId(String id) =>
      (select(budgets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Budget>> changedSince(int since) async {
    return (select(budgets)
            ..where((t) => t.updatedAt.isBiggerOrEqualValue(since)))
        .get();
  }

  /// All category limits belonging to [budgetId].
  Future<List<CategoryBudgetLimit>> limitsFor(String budgetId) =>
      (select(limits)..where((t) => t.budgetId.equals(budgetId))).get();

  Stream<List<CategoryBudgetLimit>> watchLimitsFor(String budgetId) =>
      (select(limits)..where((t) => t.budgetId.equals(budgetId))).watch();

  Future<void> replaceLimits(
    String budgetId,
    List<CategoryBudgetLimitsCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(limits)..where((t) => t.budgetId.equals(budgetId))).go();
      if (rows.isNotEmpty) {
        await batch((b) => b.insertAll(limits, rows));
      }
    });
  }

  /// Number of spending limits per budget — used to keep the budget list
  /// lightweight without fetching every limit row.
  Stream<List<CategoryBudgetLimit>> watchAllLimits() => select(limits).watch();
}
