import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Mp2Accounts], [Mp2Contributions], [Mp2Withdrawals], and
/// [Mp2Dividends]. All SQL for MP2 is scoped here.
class Mp2Dao extends DatabaseAccessor<AppDatabase> {
  Mp2Dao(super.db);

  $Mp2AccountsTable get mp2Accounts => attachedDatabase.mp2Accounts;

  $Mp2ContributionsTable get mp2Contributions =>
      attachedDatabase.mp2Contributions;

  $Mp2WithdrawalsTable get mp2Withdrawals => attachedDatabase.mp2Withdrawals;

  $Mp2DividendsTable get mp2Dividends => attachedDatabase.mp2Dividends;

  Future<Mp2Account> insert(Mp2AccountsCompanion entry) async {
    return into(mp2Accounts).insertReturning(entry);
  }

  Future<int> updateEntry(Mp2AccountsCompanion entry) async {
    return (update(mp2Accounts)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(mp2Accounts)..where((t) => t.id.equals(id))).write(
      Mp2AccountsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<int> reopen(String id, {required int nowMillis}) {
    return (update(mp2Accounts)..where((t) => t.id.equals(id))).write(
      Mp2AccountsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: const Value(null),
      ),
    );
  }

  Stream<List<Mp2Account>> watchActive() =>
      (select(mp2Accounts)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<Mp2Account>> active() =>
      (select(mp2Accounts)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<Mp2Account>> watchArchived() =>
      (select(mp2Accounts)..where((t) => t.deletedAt.isNotNull())).watch();

  Future<List<Mp2Account>> archived() =>
      (select(mp2Accounts)..where((t) => t.deletedAt.isNotNull())).get();

  Future<Mp2Account?> byId(String id) =>
      (select(mp2Accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Mp2Contribution>> contributionsFor(String mp2AccountId) =>
      (select(mp2Contributions)
            ..where((t) => t.mp2AccountId.equals(mp2AccountId)))
          .get();

  Stream<List<Mp2Contribution>> watchContributionsFor(String mp2AccountId) =>
      (select(mp2Contributions)
            ..where((t) => t.mp2AccountId.equals(mp2AccountId)))
          .watch();

  /// Contributions to [mp2AccountId] dated in the half-open window
  /// `[fromMillis, toMillis)`.
  Future<List<Mp2Contribution>> contributionsBetween(
    String mp2AccountId, {
    required int fromMillis,
    required int toMillis,
  }) =>
      (select(mp2Contributions)
            ..where((t) =>
                t.mp2AccountId.equals(mp2AccountId) &
                t.contributedOn.isBiggerOrEqualValue(fromMillis) &
                t.contributedOn.isSmallerThanValue(toMillis)))
          .get();

  Future<void> insertContribution(Mp2ContributionsCompanion entry) async {
    await into(mp2Contributions).insert(entry);
  }

  Future<List<Mp2Withdrawal>> withdrawalsFor(String mp2AccountId) =>
      (select(mp2Withdrawals)
            ..where((t) => t.mp2AccountId.equals(mp2AccountId)))
          .get();

  Stream<List<Mp2Withdrawal>> watchWithdrawalsFor(String mp2AccountId) =>
      (select(mp2Withdrawals)
            ..where((t) => t.mp2AccountId.equals(mp2AccountId)))
          .watch();

  Future<void> insertWithdrawal(Mp2WithdrawalsCompanion entry) async {
    await into(mp2Withdrawals).insert(entry);
  }

  Future<List<Mp2Dividend>> dividendsFor(String mp2AccountId) =>
      (select(mp2Dividends)
            ..where((t) => t.mp2AccountId.equals(mp2AccountId)))
          .get();

  Stream<List<Mp2Dividend>> watchDividendsFor(String mp2AccountId) =>
      (select(mp2Dividends)
            ..where((t) => t.mp2AccountId.equals(mp2AccountId)))
          .watch();

  /// The dividend year indices already realized for [mp2AccountId].
  Future<Set<int>> realizedDividendYears(String mp2AccountId) async {
    final rows = await dividendsFor(mp2AccountId);
    return {for (final d in rows) d.year};
  }

  Future<void> insertDividend(Mp2DividendsCompanion entry) async {
    await into(mp2Dividends).insert(entry);
  }
}
