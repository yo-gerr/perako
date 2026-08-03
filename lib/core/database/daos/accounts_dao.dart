import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Accounts]. All SQL for accounts is scoped here.
class AccountsDao extends DatabaseAccessor<AppDatabase> {
  AccountsDao(super.db);

  $AccountsTable get accounts => attachedDatabase.accounts;

  Future<Account> insertAccount(AccountsCompanion entry) async {
    return into(accounts).insertReturning(entry);
  }

  Future<void> bulkInsertAccounts(List<AccountsCompanion> rows) =>
      batch((b) => b.insertAll(accounts, rows));

  Future<int> updateAccount(AccountsCompanion entry) async {
    return (update(accounts)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  /// Inserts [entry] or updates the existing row with the same id.
  Future<void> upsert(AccountsCompanion entry) async {
    final existing = await byId(entry.id.value);
    if (existing == null) {
      await insertAccount(entry);
    } else {
      await updateAccount(entry);
    }
  }

  /// Soft-deletes (tombstones) an account by setting `deleted_at`.
  Future<int> archive(String id, {required int nowMillis}) {
    return (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Stream<List<Account>> watchActive() => (select(accounts)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Future<List<Account>> active() async =>
      (select(accounts)..where((t) => t.deletedAt.isNull())).get();

  Future<List<Account>> all() => select(accounts).get();

  Future<Account?> byId(String id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Rows changed at or after [since] epoch-millis, for the sync push cursor.
  Future<List<Account>> changedSince(int since) async {
    return (select(accounts)
            ..where((t) => t.updatedAt.isBiggerThanValue(since)))
        .get();
  }
}