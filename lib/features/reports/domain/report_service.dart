import '../../../core/constants.dart';
import '../../../core/database/daos/accounts_dao.dart';
import '../../../core/database/daos/ledger_dao.dart';

/// Bucketing resolution for time-series reports.
enum ReportResolution { daily, weekly, monthly }

/// Picks a sensible bucket size for a range length.
ReportResolution resolveForRange(DateTime from, DateTime to) {
  final days = to.difference(from).inDays;
  if (days <= 120) return ReportResolution.daily;
  if (days <= 700) return ReportResolution.weekly;
  return ReportResolution.monthly;
}

/// A single net-worth observation: the sum of all active account balances as
/// of the end of a bucket.
class NetWorthPoint {
  const NetWorthPoint({required this.date, required this.cents});

  final DateTime date;
  final int cents;

  @override
  bool operator ==(Object other) =>
      other is NetWorthPoint &&
      other.date == date &&
      other.cents == cents;

  @override
  int get hashCode => Object.hash(date, cents);
}

/// Income and expense within a single bucket.
class CashFlowPoint {
  const CashFlowPoint({
    required this.date,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime date;
  final int incomeCents;
  final int expenseCents;

  @override
  bool operator ==(Object other) =>
      other is CashFlowPoint &&
      other.date == date &&
      other.incomeCents == incomeCents &&
      other.expenseCents == expenseCents;

  @override
  int get hashCode => Object.hash(date, incomeCents, expenseCents);
}

/// A category-scoped income or expense total.
class CategoryAmount {
  const CategoryAmount({required this.categoryId, required this.cents});

  final String? categoryId;
  final int cents;

  @override
  bool operator ==(Object other) =>
      other is CategoryAmount &&
      other.categoryId == categoryId &&
      other.cents == cents;

  @override
  int get hashCode => Object.hash(categoryId, cents);
}

/// Derives analytics directly from the ledger. Nothing here is stored; every
/// report is recomputed from the authoritative ledger entries.
class ReportService {
  ReportService({required this.ledgerDao, required this.accountsDao});

  final LedgerDao ledgerDao;
  final AccountsDao accountsDao;

  /// The end-of-period dates that define [resolution] buckets within the
  /// inclusive range `[from, to]`.
  ///
  /// - daily: every calendar day.
  /// - weekly: 7-day windows anchored to [from].
  /// - monthly: every calendar month end.
  List<DateTime> bucketEnds({
    required DateTime from,
    required DateTime to,
    required ReportResolution resolution,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final ends = <DateTime>[];

    switch (resolution) {
      case ReportResolution.daily:
        var day = start;
        while (!day.isAfter(end)) {
          ends.add(DateTime(day.year, day.month, day.day + 1)
              .subtract(const Duration(milliseconds: 1)));
          day = DateTime(day.year, day.month, day.day + 1);
        }
      case ReportResolution.weekly:
        var day = start;
        while (!day.isAfter(end)) {
          ends.add(DateTime(day.year, day.month, day.day + 7)
              .subtract(const Duration(milliseconds: 1)));
          day = DateTime(day.year, day.month, day.day + 7);
        }
      case ReportResolution.monthly:
        var month = DateTime(from.year, from.month, 1);
        final lastMonth = DateTime(to.year, to.month, 1);
        while (!month.isAfter(lastMonth)) {
          ends.add(DateTime(month.year, month.month + 1, 1)
              .subtract(const Duration(milliseconds: 1)));
          month = DateTime(month.year, month.month + 1, 1);
        }
    }
    return ends;
  }

  /// Net worth as of the end of each bucket in `[from, to]`.
  ///
  /// Balances before [from] contribute to the starting values, so the series
  /// is continuous rather than a windowed delta.
  Future<List<NetWorthPoint>> netWorthSeries({
    required DateTime from,
    required DateTime to,
    required ReportResolution resolution,
  }) async {
    final accounts = await accountsDao.active();
    final accountIds = {for (final a in accounts) a.id};
    final entries = await ledgerDao.entriesUpTo(to.millisecondsSinceEpoch);
    entries.sort((a, b) => a.entryDate.compareTo(b.entryDate));

    final balances = <String, int>{};
    int index = 0;
    final points = <NetWorthPoint>[];

    for (final bucketEnd in bucketEnds(
      from: from,
      to: to,
      resolution: resolution,
    )) {
      final asOf = bucketEnd.millisecondsSinceEpoch;
      while (index < entries.length &&
          entries[index].entryDate <= asOf) {
        final e = entries[index];
        if (accountIds.contains(e.accountId)) {
          final signed = e.type == 'debit' ? e.amount : -e.amount;
          balances[e.accountId] = (balances[e.accountId] ?? 0) + signed;
        }
        index++;
      }
      var total = 0;
      for (final id in accountIds) {
        total += balances[id] ?? 0;
      }
      points.add(NetWorthPoint(
        date: bucketEnd,
        cents: total,
      ));
    }
    return points;
  }

  /// Income and expense within each bucket of `[from, to]`.
  Future<List<CashFlowPoint>> cashFlowSeries({
    required DateTime from,
    required DateTime to,
    required ReportResolution resolution,
  }) async {
    final entries = await ledgerDao.entriesUpTo(to.millisecondsSinceEpoch);
    final ends = bucketEnds(from: from, to: to, resolution: resolution);
    final points = <CashFlowPoint>[];

    var windowStart = from.millisecondsSinceEpoch;
    for (final bucketEnd in ends) {
      var income = 0;
      var expense = 0;
      for (final e in entries) {
        if (e.entryDate < windowStart) continue;
        if (e.entryDate > bucketEnd.millisecondsSinceEpoch) continue;
        if (e.accountId == LedgerConstants.counterpartyIncome &&
            e.type == 'credit') {
          income += e.amount;
        } else if (e.accountId == LedgerConstants.counterpartyExpense &&
            e.type == 'debit') {
          expense += e.amount;
        }
      }
      points.add(CashFlowPoint(
        date: bucketEnd,
        incomeCents: income,
        expenseCents: expense,
      ));
      windowStart = bucketEnd.millisecondsSinceEpoch + 1;
    }
    return points;
  }

  /// Spending grouped by category within `[from, to]`.
  Future<List<CategoryAmount>> expenseByCategory({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await ledgerDao.expenseByCategory(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    return [
      for (final (id, cents) in rows)
        CategoryAmount(categoryId: id, cents: cents),
    ];
  }

  /// Income grouped by category within `[from, to]`.
  Future<List<CategoryAmount>> incomeByCategory({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await ledgerDao.incomeByCategory(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    return [
      for (final (id, cents) in rows)
        CategoryAmount(categoryId: id, cents: cents),
    ];
  }

  // ---- CSV export -------------------------------------------------------

  static String csvForNetWorth(List<NetWorthPoint> points) {
    final lines = [
      _csvRow(['Date', 'Net worth (cents)']),
      for (final p in points)
        _csvRow([
          '${p.date.year}-${p.date.month}-${p.date.day}',
          '${p.cents}',
        ]),
    ];
    return lines.join('\n');
  }

  static String csvForCashFlow(List<CashFlowPoint> points) {
    final lines = [
      _csvRow(['Date', 'Income (cents)', 'Expense (cents)']),
      for (final p in points)
        _csvRow([
          '${p.date.year}-${p.date.month}-${p.date.day}',
          '${p.incomeCents}',
          '${p.expenseCents}',
        ]),
    ];
    return lines.join('\n');
  }

  static String csvForCategory(
    List<CategoryAmount> rows,
    Map<String, String> names, {
    required String column,
  }) {
    final lines = [
      _csvRow(['Category', '$column (cents)']),
      for (final r in rows)
        _csvRow([
          r.categoryId == null ? 'Uncategorized' : (names[r.categoryId!] ?? ''),
          '${r.cents}',
        ]),
    ];
    return lines.join('\n');
  }

  static String _csvRow(List<String> cells) =>
      cells.map(_csvEscape).join(',');

  static String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
