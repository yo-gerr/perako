import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [TimeDeposits]. All SQL for time deposits is scoped here.
class TimeDepositsDao extends DatabaseAccessor<AppDatabase> {
  TimeDepositsDao(super.db);

  $TimeDepositsTable get timeDeposits => attachedDatabase.timeDeposits;

  Future<TimeDeposit> insert(TimeDepositsCompanion entry) async {
    return into(timeDeposits).insertReturning(entry);
  }

  Future<int> updateEntry(TimeDepositsCompanion entry) async {
    return (update(timeDeposits)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(timeDeposits)..where((t) => t.id.equals(id))).write(
      TimeDepositsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<int> reopen(String id, {required int nowMillis}) {
    return (update(timeDeposits)..where((t) => t.id.equals(id))).write(
      TimeDepositsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: const Value(null),
      ),
    );
  }

  Stream<List<TimeDeposit>> watchActive() =>
      (select(timeDeposits)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<TimeDeposit>> active() =>
      (select(timeDeposits)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<TimeDeposit>> watchArchived() =>
      (select(timeDeposits)..where((t) => t.deletedAt.isNotNull())).watch();

  Future<List<TimeDeposit>> archived() =>
      (select(timeDeposits)..where((t) => t.deletedAt.isNotNull())).get();

  Future<TimeDeposit?> byId(String id) =>
      (select(timeDeposits)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TimeDeposit>> activeForAccount(String accountId) =>
      (select(timeDeposits)
            ..where((t) => t.deletedAt.isNull() & t.accountId.equals(accountId)))
          .get();

  /// Active deposits whose maturity date has arrived but which have not yet
  /// been marked matured, oldest maturity first.
  Future<List<TimeDeposit>> dueToMature(int nowMillis) => (select(timeDeposits)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.isMatured.equals(false) &
            t.maturityDate.isSmallerOrEqualValue(nowMillis))
        ..orderBy([(t) => OrderingTerm.asc(t.maturityDate)]))
      .get();

  /// Marks [id] as matured, recording the interest transaction when one was
  /// posted. [maturedTransactionId] is null when the deposit earned nothing.
  Future<void> markMatured(
    String id, {
    required String? maturedTransactionId,
    required int maturityValueCents,
    required int nowMillis,
  }) async {
    await (update(timeDeposits)..where((t) => t.id.equals(id))).write(
      TimeDepositsCompanion(
        maturityValueCents: Value(maturityValueCents),
        isMatured: const Value(true),
        maturedTransactionId: Value(maturedTransactionId),
        updatedAt: Value(nowMillis),
      ),
    );
  }
}
