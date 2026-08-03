import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Transaction]s. All SQL for transactions is scoped here.
class TransactionsDao extends DatabaseAccessor<AppDatabase> {
  TransactionsDao(super.db);

  $TransactionsTable get transactions => attachedDatabase.transactions;

  Future<Transaction> insertTransaction(TransactionsCompanion entry) async {
    return into(transactions).insertReturning(entry);
  }

  Future<void> bulkInsertTransactions(List<TransactionsCompanion> rows) =>
      batch((b) => b.insertAll(transactions, rows));

  Future<int> updateTransaction(TransactionsCompanion entry) async {
    return (update(transactions)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<Transaction?> byId(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Transaction>> activeBetween(DateTime from, DateTime to) =>
      (select(transactions)
            ..where((t) =>
                t.deletedAt.isNull() &
                t.date.isBiggerOrEqualValue(from.millisecondsSinceEpoch) &
                t.date.isSmallerOrEqualValue(to.millisecondsSinceEpoch))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Stream<List<Transaction>> watchRecent({int limit = 50}) {
    final q = select(transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(limit);
    return q.watch();
  }

  Future<List<Transaction>> changedSince(int since) async {
    return (select(transactions)
            ..where((t) => t.updatedAt.isBiggerOrEqualValue(since)))
        .get();
  }
}