import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Bills] and [BillPayments]. All SQL for bills is scoped
/// here.
class BillsDao extends DatabaseAccessor<AppDatabase> {
  BillsDao(super.db);

  $BillsTable get bills => attachedDatabase.bills;

  $BillPaymentsTable get billPayments => attachedDatabase.billPayments;

  Future<Bill> insert(BillsCompanion entry) async {
    return into(bills).insertReturning(entry);
  }

  Future<int> updateBill(BillsCompanion entry) async {
    return (update(bills)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<int> reopen(String id, {required int nowMillis}) {
    return (update(bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: const Value(null),
      ),
    );
  }

  Stream<List<Bill>> watchActive() =>
      (select(bills)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<Bill>> active() =>
      (select(bills)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<Bill>> watchArchived() =>
      (select(bills)..where((t) => t.deletedAt.isNotNull())).watch();

  Future<List<Bill>> allIncludingArchived() => select(bills).get();

  Future<Bill?> byId(String id) =>
      (select(bills)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Active bills whose next due date is at or before [nowMillis].
  Future<List<Bill>> dueBefore(int nowMillis) async {
    return (select(bills)
          ..where((t) =>
              t.deletedAt.isNull() & t.nextDueDate.isSmallerOrEqualValue(nowMillis)))
        .get();
  }

  Future<List<Bill>> changedSince(int since) async {
    return (select(bills)
            ..where((t) => t.updatedAt.isBiggerOrEqualValue(since)))
        .get();
  }

  Future<BillPayment?> latestPaymentFor(String billId) {
    final q = (select(billPayments)
          ..where((t) => t.billId.equals(billId))
          ..orderBy([(t) => OrderingTerm.desc(t.paidOn)])
          ..limit(1));
    return q.getSingleOrNull();
  }

  Stream<List<BillPayment>> watchPaymentsFor(String billId) =>
      (select(billPayments)..where((t) => t.billId.equals(billId))).watch();

  Future<List<BillPayment>> paymentsFor(String billId) =>
      (select(billPayments)..where((t) => t.billId.equals(billId))).get();

  Future<void> insertPayment(BillPaymentsCompanion entry) async {
    await into(billPayments).insert(entry);
  }

  Future<void> insertPayments(Iterable<BillPaymentsCompanion> entries) async {
    await batch((b) => b.insertAll(billPayments, entries));
  }
}
