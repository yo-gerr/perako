import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/ledger_dao.dart';
import '../../../core/database/daos/transactions_dao.dart';

/// Direction of a single ledger line.
enum EntryType { debit, credit }

/// One side of a double-entry posting.
class LedgerLine {
  const LedgerLine({
    required this.accountId,
    required this.type,
    required this.amountCents,
    this.categoryId,
  });

  final String accountId;
  final EntryType type;

  /// Always a positive magnitude in integer cents.
  final int amountCents;

  final String? categoryId;

  /// Returns a companion usable directly by the DAO.
  LedgerEntriesCompanion toCompanion({
    required String id,
    required String transactionId,
    required int entryDateMillis,
    required int nowMillis,
  }) {
    return LedgerEntriesCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      amount: Value(amountCents),
      type: Value(type.name),
      entryDate: Value(entryDateMillis),
      updatedAt: Value(nowMillis),
      version: const Value(1),
    );
  }
}

/// Thrown when a transaction cannot be posted because it violates
/// double-entry integrity.
class UnbalancedTransaction implements Exception {
  const UnbalancedTransaction(this.debits, this.credits);

  final int debits;
  final int credits;

  @override
  String toString() =>
      'Unbalanced transaction: debits=$debits != credits=$credits';
}

class NegativeAmountException implements Exception {
  const NegativeAmountException(this.amountCents);
  final int amountCents;

  @override
  String toString() => 'Amount must be positive, got $amountCents';
}

class EmptyTransactionException implements Exception {
  const EmptyTransactionException();
  @override
  String toString() => 'A transaction must contain at least one ledger line';
}

/// The Ledger Engine — the heart of PeraKo.
///
/// Implements double-entry bookkeeping over the local SQLite database:
/// every financial event is stored as a balanced set of [LedgerEntry]s, and
/// balances are never stored directly, only derived from those entries.
class LedgerEngine {
  LedgerEngine({
    required AppDatabase db,
    String Function()? idGenerator,
    int Function()? clock,
  })  : _db = db,
        _ledgerDao = LedgerDao(db),
        _transactionsDao = TransactionsDao(db),
        _idGen = idGenerator ?? LedgerEngine._uuid,
        _clock = clock ?? LedgerEngine._now;

  final AppDatabase _db;
  final LedgerDao _ledgerDao;
  final TransactionsDao _transactionsDao;
  final String Function() _idGen;
  final int Function() _clock;

  /// Validates that total debits equal total credits, amounts are non-negative,
  /// and at least one line exists. Throws on violation.
  void validateTransaction(Iterable<LedgerLine> lines) {
    final list = lines.toList();
    if (list.isEmpty) {
      throw const EmptyTransactionException();
    }
    int debits = 0;
    int credits = 0;
    for (final line in list) {
      if (line.amountCents < 0) {
        throw NegativeAmountException(line.amountCents);
      }
      switch (line.type) {
        case EntryType.debit:
          debits += line.amountCents;
        case EntryType.credit:
          credits += line.amountCents;
      }
    }
    if (debits != credits) {
      throw UnbalancedTransaction(debits, credits);
    }
  }

  /// Posts a transaction atomically: inserts the [Transaction] header and its
  /// balanced ledger entries in a single DB transaction.
  ///
  /// [on] is the business date (defaults to now). Returns the created id.
  Future<String> postTransaction({
    required String description,
    required List<LedgerLine> lines,
    DateTime? on,
    String? notes,
  }) async {
    validateTransaction(lines);
    final txId = _idGen();
    final now = _clock();
    final dateMillis = (on ?? DateTime.fromMillisecondsSinceEpoch(now))
        .millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _transactionsDao.insertTransaction(
        TransactionsCompanion(
          id: Value(txId),
          description: Value(description),
          date: Value(dateMillis),
          notes: Value(notes),
          updatedAt: Value(now),
          version: const Value(1),
        ),
      );
      await _ledgerDao.insertEntries(
        lines.map((l) => l.toCompanion(
              id: _idGen(),
              transactionId: txId,
              entryDateMillis: dateMillis,
              nowMillis: now,
            )),
      );
    });
    return txId;
  }

  /// Reverses a transaction by posting mirrored ledger entries under a new
  /// transaction, preserving the audit trail. Original entries are untouched.
  Future<String> reverseTransaction(String transactionId) async {
    final existing = await _ledgerDao.forTransaction(transactionId);
    if (existing.isEmpty) {
      throw StateError('No ledger entries found for transaction $transactionId');
    }

    final lines = existing.map((e) => LedgerLine(
          accountId: e.accountId,
          categoryId: e.categoryId,
          // Reverse the direction.
          type: e.type == 'debit' ? EntryType.credit : EntryType.debit,
          amountCents: e.amount,
        ));

    return postTransaction(
      description: 'Reversal of $transactionId',
      lines: lines.toList(),
    );
  }

  /// Current net balance for [accountId] in integer cents (debits minus
  /// credits), optionally as-of [asOf] date.
  Future<int> getBalance(String accountId, {DateTime? asOf}) =>
      _ledgerDao.balance(
        accountId,
        asOfMillis: asOf?.millisecondsSinceEpoch,
      );

  /// Net worth: gross assets (total debits) minus gross liabilities
  /// (total credits) across the whole ledger.
  Future<int> getNetWorth() async {
    final (debits, credits) = await _ledgerDao.totals();
    return debits - credits;
  }

  /// Sum of entries for a single account (debits, credits).
  Future<(int, int)> debitsAndCredits(String accountId, {DateTime? asOf}) =>
      _ledgerDao.debitsAndCredits(
        accountId,
        asOfMillis: asOf?.millisecondsSinceEpoch,
      );

  static String _uuid() =>
      // Collision-averse enough for single-user local-first.
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
  static int _counter = 0;

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}