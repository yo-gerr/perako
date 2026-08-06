import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [SavingsAccounts] and [InterestSchedules]. All SQL for the
/// savings engine is scoped here.
class SavingsDao extends DatabaseAccessor<AppDatabase> {
  SavingsDao(super.db);

  $SavingsAccountsTable get savingsAccounts =>
      attachedDatabase.savingsAccounts;

  $InterestSchedulesTable get interestSchedules =>
      attachedDatabase.interestSchedules;

  /// Inserts or updates the savings configuration for [accountId].
  Future<SavingsAccount> upsert(SavingsAccountsCompanion entry) async {
    await into(savingsAccounts).insert(
      entry,
      onConflict: DoUpdate(
        (old) => SavingsAccountsCompanion(
          interestRate: entry.interestRate,
          compoundingFrequency: entry.compoundingFrequency,
          interestCreditDay: entry.interestCreditDay,
          isPaused: entry.isPaused,
          startDate: entry.startDate,
          updatedAt: entry.updatedAt,
          version: entry.version,
        ),
      ),
    );
    return (select(savingsAccounts)
          ..where((t) => t.accountId.equals(entry.accountId.value)))
        .getSingle();
  }

  Future<SavingsAccount?> byAccountId(String accountId) =>
      (select(savingsAccounts)
            ..where((t) => t.accountId.equals(accountId)))
          .getSingleOrNull();

  /// Savings configurations whose [SavingsAccounts.deletedAt] is null.
  Future<List<SavingsAccount>> active() =>
      (select(savingsAccounts)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<SavingsAccount>> watchActive() =>
      (select(savingsAccounts)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<InterestSchedule>> schedulesFor(String accountId) =>
      (select(interestSchedules)
            ..where((t) => t.savingsAccountId.equals(accountId)))
          .get();

  Stream<List<InterestSchedule>> watchSchedulesFor(String accountId) =>
      (select(interestSchedules)
            ..where((t) => t.savingsAccountId.equals(accountId)))
          .watch();

  Future<List<InterestSchedule>> existingDueDates(String accountId) =>
      (select(interestSchedules)
            ..where((t) => t.savingsAccountId.equals(accountId)))
          .get();

  Future<void> insertSchedule(InterestSchedulesCompanion entry) async {
    await into(interestSchedules).insert(entry);
  }

  /// Unposted schedules whose due date has arrived, for every active savings
  /// account, oldest due date first so each credit sees the prior ones posted.
  Future<List<InterestSchedule>> dueUnposted(int nowMillis) async {
    final activeAccounts =
        (select(savingsAccounts)..where((t) => t.deletedAt.isNull())).get();
    final accountIds = {
      for (final a in await activeAccounts) a.accountId,
    };
    return (select(interestSchedules)
          ..where((t) =>
              t.transactionId.isNull() &
              t.dueDate.isSmallerOrEqualValue(nowMillis) &
              t.savingsAccountId.isIn(accountIds))
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .get();
  }

  /// Marks [scheduleId] as realized. [transactionId] is null when the credit
  /// earned nothing and no posting was generated.
  Future<void> markPosted(
    String scheduleId, {
    required String? transactionId,
    required int principalCents,
    required int interestCents,
  }) async {
    await (update(interestSchedules)
          ..where((t) => t.id.equals(scheduleId)))
        .write(InterestSchedulesCompanion(
      transactionId: Value(transactionId),
      principalCents: Value(principalCents),
      interestCents: Value(interestCents),
    ));
  }
}
