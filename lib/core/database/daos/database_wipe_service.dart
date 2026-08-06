import '../app_database.dart';

/// Deletes all locally-stored ledger data and sync cursors.
///
/// Called when a different account signs in on the same device. SQLite is a
/// local mirror; Firestore (scoped per user) is authoritative, so a fresh user
/// starts from an empty local DB and pulls their own data.
class DatabaseWipeService {
  DatabaseWipeService(this._db);

  final AppDatabase _db;

  Future<void> wipeAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.profiles).go();
      await _db.delete(_db.categoryBudgetLimits).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.transactionTags).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.ledgerEntries).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.syncState).go();
    });
  }
}