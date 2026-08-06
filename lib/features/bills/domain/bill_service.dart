import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/bills_dao.dart';
import '../../ledger/domain/ledger_engine.dart';
import '../../transactions/domain/transaction_posting.dart';

/// Recurrence of a [Bills] row.
enum BillFrequency {
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const BillFrequency(this.label);

  final String label;

  static BillFrequency fromKey(String key) => BillFrequency.values.firstWhere(
        (f) => f.name == key,
        orElse: () => BillFrequency.monthly,
      );
}

/// The bill engine: computes the next due date and materializes due bills as
/// balanced ledger expenses, recording each payment for the audit trail.
class BillService {
  BillService({
    required this._db,
    required this._engine,
    required this._billsDao,
  });

  final AppDatabase _db;
  final LedgerEngine _engine;
  final BillsDao _billsDao;

  bool _running = false;

  /// The day of the month to anchor [frequency] recurrence. Falls back to the
  /// anchor's own day when the bill has no explicit [Bills.dayOfMonth].
  int _anchorDay(Bill bill, DateTime anchor) => bill.dayOfMonth ?? anchor.day;

  /// The next due date after [anchor], following the bill's [BillFrequency].
  ///
  /// Monthly and yearly recurrence clamp the day to the target month's length,
  /// so Jan 31 rolls to Feb 28 rather than Mar 3.
  DateTime nextDueAfter(Bill bill, {DateTime? after}) {
    final anchor = after ?? DateTime.fromMillisecondsSinceEpoch(bill.nextDueDate);
    switch (BillFrequency.fromKey(bill.frequency)) {
      case BillFrequency.weekly:
        return anchor.add(const Duration(days: 7));
      case BillFrequency.monthly:
        final month = DateTime(anchor.year, anchor.month + 1, 1);
        final day = _anchorDay(bill, anchor).clamp(1, _daysInMonth(month));
        return DateTime(month.year, month.month, day, anchor.hour,
            anchor.minute, anchor.second, anchor.millisecond);
      case BillFrequency.yearly:
        final target = DateTime(anchor.year + 1, anchor.month, 1);
        final day = _anchorDay(bill, anchor).clamp(1, _daysInMonth(target));
        return DateTime(target.year, target.month, day, anchor.hour,
            anchor.minute, anchor.second, anchor.millisecond);
    }
  }

  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// The first due date for a brand-new bill: the next occurrence of
  /// [frequency] at or after [from] (defaults to now).
  ///
  /// Monthly and yearly recurrence use [dayOfMonth] (falling back to today's
  /// day); weekly is simply one week out.
  DateTime initialDueDate(
    BillFrequency frequency,
    int? dayOfMonth, {
    DateTime? from,
  }) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (frequency) {
      case BillFrequency.weekly:
        return now.add(const Duration(days: 7));
      case BillFrequency.monthly:
        final month = DateTime(now.year, now.month, 1);
        final day = (dayOfMonth ?? now.day).clamp(1, _daysInMonth(month));
        final candidate = DateTime(month.year, month.month, day);
        return candidate.isBefore(today)
            ? DateTime(now.year, now.month + 1, day)
            : candidate;
      case BillFrequency.yearly:
        final month = DateTime(now.year, now.month, 1);
        final day = (dayOfMonth ?? now.day).clamp(1, _daysInMonth(month));
        final candidate = DateTime(month.year, month.month, day);
        return candidate.isBefore(today)
            ? DateTime(now.year + 1, now.month, day)
            : candidate;
    }
  }

  /// Pays [bill] now: posts a balanced expense through the ledger (dated
  /// [on], defaulting to today), records a [BillPayments] row linking the
  /// posting, and advances the schedule — all in one transaction.
  ///
  /// Returns the id of the generated transaction.
  Future<String> payBill(
    Bill bill, {
    DateTime? on,
    String? note,
  }) async {
    final paidOn = on ?? DateTime.now();
    final txId = await _db.transaction(() async {
      final id = await _engine.postTransaction(
        description: 'Payment for ${bill.name}',
        on: paidOn,
        notes: note,
        lines: buildLedgerLines(
          type: TxType.expense,
          accountId: bill.accountId,
          categoryId: bill.categoryId,
          amountCents: bill.amountCents,
        ),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await _billsDao.insertPayment(BillPaymentsCompanion(
        id: Value(_nextId()),
        billId: Value(bill.id),
        transactionId: Value(id),
        amountCents: Value(bill.amountCents),
        paidOn: Value(paidOn.millisecondsSinceEpoch),
        note: Value(note),
        createdAt: Value(now),
      ));
      final nextDue = nextDueAfter(bill, after: paidOn);
      await _billsDao.updateBill(BillsCompanion(
        id: Value(bill.id),
        updatedAt: Value(now),
        nextDueDate: Value(nextDue.millisecondsSinceEpoch),
      ));
      return id;
    });
    return txId;
  }

  /// Materializes every active bill whose due date has passed. Idempotent:
  /// each bill is paid once and its schedule advanced past [now].
  Future<int> catchUpDueBills({DateTime? now}) async {
    if (_running) return 0;
    _running = true;
    try {
      final cutoff = now ?? DateTime.now();
      final due = await _billsDao.dueBefore(cutoff.millisecondsSinceEpoch);
      for (final bill in due) {
        await payBill(
          bill,
          on: DateTime.fromMillisecondsSinceEpoch(bill.nextDueDate),
        );
      }
      return due.length;
    } finally {
      _running = false;
    }
  }

  static int _counter = 0;

  static String _nextId() =>
      'pay_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}
