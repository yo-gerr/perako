import 'package:drift/drift.dart';

import '../../../core/constants.dart';
import '../app_database.dart';

/// Persistence for ledger entries. All SQL for the ledger is scoped here.
///
/// Balances are never stored — they are always derived from these entries.
class LedgerDao extends DatabaseAccessor<AppDatabase> {
  LedgerDao(super.db);

  $LedgerEntriesTable get ledgerEntries => attachedDatabase.ledgerEntries;

  /// Algebraic sum of [amount] across non-deleted entries matching [filter].
  /// Debits are subtracted, credits are added back to the returned total.
  Future<int> _sumOf(
    Expression<bool> Function($LedgerEntriesTable t) filter,
    {required int sign,
  }) async {
    final q = selectOnly(ledgerEntries);
    final sum = ledgerEntries.amount.sum();
    q.addColumns([sum]);
    q.where(filter(ledgerEntries));
    final row = await q.getSingle();
    final value = row.read(sum) ?? 0;
    return sign * value;
  }

  /// Inserts a set of ledger entries. Caller is responsible for validating
  /// that debits == credits before invoking this.
  Future<void> insertEntries(Iterable<LedgerEntriesCompanion> entries) async {
    await batch((b) => b.insertAll(ledgerEntries, entries.toList()));
  }

  /// The +net balance for [accountId] (all debits minus all credits), up to
  /// [asOfMillis] when provided, else across all time.
  Future<int> balance(String accountId, {int? asOfMillis}) async {
    final upTo = asOfMillis ?? _maxBound;
    final debits = await _sumOf(
      (t) =>
          t.accountId.equals(accountId) &
          t.type.equals('debit') &
          t.deletedAt.isNull() &
          t.entryDate.isSmallerOrEqualValue(upTo),
      sign: 1,
    );
    final credits = await _sumOf(
      (t) =>
          t.accountId.equals(accountId) &
          t.type.equals('credit') &
          t.deletedAt.isNull() &
          t.entryDate.isSmallerOrEqualValue(upTo),
      sign: -1,
    );
    return debits + credits;
  }

  /// Gross debit total and gross credit total for [accountId] as
  /// `(debits, credits)` in integer cents (all positive magnitudes).
  Future<(int, int)> debitsAndCredits(
    String accountId, {
    int? asOfMillis,
  }) async {
    final upTo = asOfMillis ?? _maxBound;
    final debits = await _sumOf(
      (t) =>
          t.accountId.equals(accountId) &
          t.type.equals('debit') &
          t.deletedAt.isNull() &
          t.entryDate.isSmallerOrEqualValue(upTo),
      sign: 1,
    );
    final credits = await _sumOf(
      (t) =>
          t.accountId.equals(accountId) &
          t.type.equals('credit') &
          t.deletedAt.isNull() &
          t.entryDate.isSmallerOrEqualValue(upTo),
      sign: 1,
    );
    return (debits, credits);
  }

  /// Full-ledger debit and credit totals as `(debits, credits)`.
  Future<(int, int)> totals() async {
    final debits = await _sumOf(
      (t) => t.type.equals('debit') & t.deletedAt.isNull(),
      sign: 1,
    );
    final credits = await _sumOf(
      (t) => t.type.equals('credit') & t.deletedAt.isNull(),
      sign: 1,
    );
    return (debits, credits);
  }

  /// Income and expense in integer cents for the inclusive millisecond range
  /// `[fromMillis, toMillis]`, derived from the hidden income/expense corpora.
  Future<(int, int)> cashFlow(int fromMillis, int toMillis) async {
    final income = await _sumOf(
      (t) =>
          t.accountId.equals(LedgerConstants.counterpartyIncome) &
          t.type.equals('credit') &
          t.deletedAt.isNull() &
          t.entryDate.isBiggerOrEqualValue(fromMillis) &
          t.entryDate.isSmallerOrEqualValue(toMillis),
      sign: 1,
    );
    final expense = await _sumOf(
      (t) =>
          t.accountId.equals(LedgerConstants.counterpartyExpense) &
          t.type.equals('debit') &
          t.deletedAt.isNull() &
          t.entryDate.isBiggerOrEqualValue(fromMillis) &
          t.entryDate.isSmallerOrEqualValue(toMillis),
      sign: 1,
    );
    return (income, expense);
  }

  Future<List<LedgerEntry>> forTransaction(String transactionId) =>
      (select(ledgerEntries)
            ..where((t) =>
                t.transactionId.equals(transactionId) & t.deletedAt.isNull()))
          .get();

  /// All non-deleted ledger entries with [LedgerEntries.entryDate] at or
  /// before [toMillis]. Used to derive balances as-of arbitrary dates.
  Future<List<LedgerEntry>> entriesUpTo(int toMillis) async {
    return (select(ledgerEntries)
          ..where((t) =>
              t.deletedAt.isNull() & t.entryDate.isSmallerOrEqualValue(toMillis)))
        .get();
  }

  /// Spending grouped by category within the inclusive millisecond range, as
  /// `(categoryId, cents)` pairs. Uncategorized expenses appear with a null
  /// category id. Derived from the hidden expense corpus.
  Future<List<(String?, int)>> expenseByCategory(
    int fromMillis,
    int toMillis,
  ) async {
    final q = selectOnly(ledgerEntries);
    final categoryId = ledgerEntries.categoryId;
    final sum = ledgerEntries.amount.sum();
    q.addColumns([categoryId, sum]);
    q.where(
      ledgerEntries.accountId.equals(LedgerConstants.counterpartyExpense) &
          ledgerEntries.type.equals('debit') &
          ledgerEntries.deletedAt.isNull() &
          ledgerEntries.entryDate.isBiggerOrEqualValue(fromMillis) &
          ledgerEntries.entryDate.isSmallerOrEqualValue(toMillis),
    );
    q.groupBy([categoryId]);
    final rows = await q.get();
    return [
      for (final row in rows)
        (row.read(categoryId), row.read(sum) ?? 0),
    ];
  }

  /// Income grouped by category within the inclusive millisecond range, as
  /// `(categoryId, cents)` pairs. Uncategorized income appears with a null
  /// category id. Derived from the hidden income corpus.
  Future<List<(String?, int)>> incomeByCategory(
    int fromMillis,
    int toMillis,
  ) async {
    final q = selectOnly(ledgerEntries);
    final categoryId = ledgerEntries.categoryId;
    final sum = ledgerEntries.amount.sum();
    q.addColumns([categoryId, sum]);
    q.where(
      ledgerEntries.accountId.equals(LedgerConstants.counterpartyIncome) &
          ledgerEntries.type.equals('credit') &
          ledgerEntries.deletedAt.isNull() &
          ledgerEntries.entryDate.isBiggerOrEqualValue(fromMillis) &
          ledgerEntries.entryDate.isSmallerOrEqualValue(toMillis),
    );
    q.groupBy([categoryId]);
    final rows = await q.get();
    return [
      for (final row in rows)
        (row.read(categoryId), row.read(sum) ?? 0),
    ];
  }

  /// Spending in integer cents within the inclusive millisecond range.
  ///
  /// Spending is measured on the hidden expense corpus (debit legs tagged with
  /// a category). [categoryId] filters those entries directly; [accountId]
  /// matches the real account credited by the same transaction, so
  /// account-scoped budgets exclude transfers.
  Future<int> spentCents({
    required int fromMillis,
    required int toMillis,
    String? categoryId,
    String? accountId,
  }) async {
    if (accountId == null) {
      return _sumOf(
        (t) =>
            t.accountId.equals(LedgerConstants.counterpartyExpense) &
            t.type.equals('debit') &
            t.deletedAt.isNull() &
            t.entryDate.isBiggerOrEqualValue(fromMillis) &
            t.entryDate.isSmallerOrEqualValue(toMillis) &
            (categoryId == null
                ? const Constant(true)
                : t.categoryId.equals(categoryId)),
        sign: 1,
      );
    }
    final corpus = ledgerEntries.createAlias('corpus');
    final q = selectOnly(ledgerEntries);
    final sum = ledgerEntries.amount.sum();
    q.addColumns([sum]);
    q.join([
      innerJoin(
        corpus,
        corpus.transactionId.equalsExp(ledgerEntries.transactionId),
      ),
    ]);
    q.where(
      ledgerEntries.accountId.equals(accountId) &
          ledgerEntries.type.equals('credit') &
          ledgerEntries.deletedAt.isNull() &
          ledgerEntries.entryDate.isBiggerOrEqualValue(fromMillis) &
          ledgerEntries.entryDate.isSmallerOrEqualValue(toMillis) &
          corpus.accountId.equals(LedgerConstants.counterpartyExpense) &
          corpus.deletedAt.isNull(),
    );
    final row = await q.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<List<LedgerEntry>> entriesForAccount(
    String accountId, {
    int? limit,
  }) {
    final q = select(ledgerEntries)
      ..where((t) => t.accountId.equals(accountId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  /// Stream that emits whenever any non-deleted ledger entry changes. Used to
  /// trigger reactive recalculation of derived balances.
  Stream<List<LedgerEntry>> changes() =>
      (select(ledgerEntries)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<LedgerEntry>> changedSince(int since) async {
    return (select(ledgerEntries)
            ..where((t) => t.updatedAt.isBiggerOrEqualValue(since)))
        .get();
  }

  static const int _maxBound = 1 << 62;
}