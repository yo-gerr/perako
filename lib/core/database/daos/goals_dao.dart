import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Goals] and [GoalContributions]. All SQL for goals is
/// scoped here.
class GoalsDao extends DatabaseAccessor<AppDatabase> {
  GoalsDao(super.db);

  $GoalsTable get goals => attachedDatabase.goals;

  $GoalContributionsTable get goalContributions =>
      attachedDatabase.goalContributions;

  Future<Goal> insert(GoalsCompanion entry) async {
    return into(goals).insertReturning(entry);
  }

  Future<int> updateGoal(GoalsCompanion entry) async {
    return (update(goals)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<int> reopen(String id, {required int nowMillis}) {
    return (update(goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: const Value(null),
      ),
    );
  }

  Stream<List<Goal>> watchActive() =>
      (select(goals)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<Goal>> active() =>
      (select(goals)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<Goal>> watchArchived() =>
      (select(goals)..where((t) => t.deletedAt.isNotNull())).watch();

  Future<List<Goal>> allIncludingArchived() => select(goals).get();

  Future<Goal?> byId(String id) =>
      (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Goal>> changedSince(int since) async {
    return (select(goals)
            ..where((t) => t.updatedAt.isBiggerOrEqualValue(since)))
        .get();
  }

  Stream<List<GoalContribution>> watchContributionsFor(String goalId) =>
      (select(goalContributions)..where((t) => t.goalId.equals(goalId)))
          .watch();

  Future<List<GoalContribution>> contributionsFor(String goalId) =>
      (select(goalContributions)..where((t) => t.goalId.equals(goalId)))
          .get();

  Future<void> insertContribution(GoalContributionsCompanion entry) async {
    await into(goalContributions).insert(entry);
  }
}
