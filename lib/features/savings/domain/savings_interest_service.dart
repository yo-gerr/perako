import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/accounts_dao.dart';
import '../../../core/database/daos/ledger_dao.dart';
import '../../../core/database/daos/savings_dao.dart';
import '../../ledger/domain/ledger_engine.dart';
import '../../transactions/domain/transaction_posting.dart';

/// How often a savings account accrues and credits interest.
enum CompoundingFrequency {
  daily('Daily'),
  monthly('Monthly'),
  annually('Annually');

  const CompoundingFrequency(this.label);

  final String label;

  static CompoundingFrequency fromKey(String key) =>
      CompoundingFrequency.values.firstWhere(
        (f) => f.name == key,
        orElse: () => CompoundingFrequency.monthly,
      );
}

/// The savings engine: seeds planned interest credits from a savings
/// account's configuration, then realizes due credits as balanced income
/// postings through the ledger.
///
/// Interest is computed on the account's ledger balance as of each credit
/// date, so money flowing in or out between credits is reflected and prior
/// interest is compounded by the next credit.
class SavingsInterestService {
  SavingsInterestService({
    required this.db,
    required this.engine,
    required this.savingsDao,
    required this.ledgerDao,
    required this.accountsDao,
    String Function()? idGenerator,
    int Function()? clock,
  })  : _idGen = idGenerator ?? _defaultId,
        _clock = clock ?? _defaultClock;

  final AppDatabase db;
  final LedgerEngine engine;
  final SavingsDao savingsDao;
  final LedgerDao ledgerDao;
  final AccountsDao accountsDao;

  final String Function() _idGen;
  final int Function() _clock;

  bool _running = false;

  /// The days between [from] and [to] (both normalized to their calendar
  /// dates). Used to weigh the interest period.
  static int daysBetween(DateTime from, DateTime to) =>
      _dateOnly(to).difference(_dateOnly(from)).inDays;

  /// Simple interest in integer cents on [principalCents] at [annualRate]
  /// (a decimal, e.g. 0.05 for 5% p.a.) for [days] using a 365-day year.
  ///
  /// Non-positive principals earn nothing.
  static int interestOn({
    required int principalCents,
    required double annualRate,
    required int days,
  }) {
    if (principalCents <= 0 || days <= 0) return 0;
    return (principalCents * annualRate * days / 365).round();
  }

  /// The interest credit dates for a savings arrangement that started at
  /// [start], following [frequency], that fall within the inclusive
  /// date-only range `[from, to]`.
  ///
  /// - daily: every calendar day.
  /// - monthly: the [creditDay] of every month, clamped to the month length.
  /// - annually: the anniversary (month/day) of [start], clamped for short
  ///   months (Feb 29 -> Feb 28 in non-leap years).
  static List<DateTime> creditDatesBetween({
    required DateTime start,
    required CompoundingFrequency frequency,
    required int creditDay,
    required DateTime from,
    required DateTime to,
  }) {
    final startDate = _dateOnly(start);
    final lower = _dateOnly(from);
    final upper = _dateOnly(to);
    final result = <DateTime>[];
    if (upper.isBefore(lower)) return result;

    switch (frequency) {
      case CompoundingFrequency.daily:
        for (var d = lower;
            !d.isAfter(upper);
            d = d.add(const Duration(days: 1))) {
          if (d.isAfter(startDate)) result.add(d);
        }
      case CompoundingFrequency.monthly:
        final firstMonth = DateTime(lower.year, lower.month, 1);
        final lastMonth = DateTime(upper.year, upper.month, 1);
        for (var m = firstMonth;
            !m.isAfter(lastMonth);
            m = DateTime(m.year, m.month + 1, 1)) {
          final day = creditDay.clamp(1, _daysInMonth(m.year, m.month));
          final candidate = DateTime(m.year, m.month, day);
          if (!candidate.isBefore(lower) &&
              !candidate.isAfter(upper) &&
              candidate.isAfter(startDate)) {
            result.add(candidate);
          }
        }
      case CompoundingFrequency.annually:
        for (var year = lower.year; year <= upper.year; year++) {
          final day = startDate.day.clamp(1, _daysInMonth(year, startDate.month));
          final candidate = DateTime(year, startDate.month, day);
          if (!candidate.isBefore(lower) &&
              !candidate.isAfter(upper) &&
              candidate.isAfter(startDate)) {
            result.add(candidate);
          }
        }
    }
    return result;
  }

  /// The next credit date strictly after [after] for a savings arrangement
  /// starting at [start] (all dates normalized to calendar dates). Used by the
  /// detail screen to show the upcoming credit.
  static DateTime nextCreditDate({
    required DateTime start,
    required CompoundingFrequency frequency,
    required int creditDay,
    required DateTime after,
  }) {
    final from = _dateOnly(after).add(const Duration(days: 1));
    final horizon = from.add(const Duration(days: 730));
    final dates = creditDatesBetween(
      start: start,
      frequency: frequency,
      creditDay: creditDay,
      from: from,
      to: horizon,
    );
    return dates.isEmpty ? from : dates.first;
  }

  /// Seeds planned interest credits for every active, unpaused savings account
  /// from its configuration, extending the schedule to about three months past
  /// [now] (defaults to the current time). Idempotent: existing credit dates
  /// are left untouched.
  Future<void> ensureSchedules({DateTime? now}) async {
    final asOf = now ?? DateTime.fromMillisecondsSinceEpoch(_clock());
    final lookahead = asOf.add(const Duration(days: 92));
    final nowMillis = _clock();

    for (final savings in await savingsDao.active()) {
      if (savings.isPaused) continue;
      final existing = await savingsDao.existingDueDates(savings.accountId);
      final existingDates = {
        for (final s in existing) DateTime.fromMillisecondsSinceEpoch(s.dueDate),
      };
      final start = DateTime.fromMillisecondsSinceEpoch(savings.startDate);
      final lastExisting = existing.isEmpty
          ? null
          : existing
              .map((s) => DateTime.fromMillisecondsSinceEpoch(s.dueDate))
              .reduce((a, b) => a.isAfter(b) ? a : b);
      final from = lastExisting == null
          ? _dateOnly(start)
          : _dateOnly(lastExisting.add(const Duration(days: 1)));

      final dates = creditDatesBetween(
        start: start,
        frequency: CompoundingFrequency.fromKey(savings.compoundingFrequency),
        creditDay: savings.interestCreditDay,
        from: from,
        to: _dateOnly(lookahead),
      );
      for (final date in dates) {
        if (existingDates.contains(date)) continue;
        await savingsDao.insertSchedule(InterestSchedulesCompanion(
          id: Value(_idGen()),
          savingsAccountId: Value(savings.accountId),
          dueDate: Value(date.millisecondsSinceEpoch),
          createdAt: Value(nowMillis),
        ));
      }
    }
  }

  /// Realizes every unposted interest credit whose due date has arrived.
  ///
  /// Each realized credit posts a balanced income transaction into the savings
  /// account dated on the credit's due date, so compounding is deterministic
  /// and history is auditable. Returns the number of credits posted. Credits
  /// that earn nothing (paused, empty, or negative balance) are marked
  /// realized with zero interest and no transaction.
  Future<int> accrueDueInterest({DateTime? now}) async {
    if (_running) return 0;
    _running = true;
    try {
      final asOf = now ?? DateTime.fromMillisecondsSinceEpoch(_clock());
      await ensureSchedules(now: asOf);
      final due = await savingsDao.dueUnposted(asOf.millisecondsSinceEpoch);
      var credited = 0;
      for (final schedule in due) {
        final savings = await savingsDao.byAccountId(schedule.savingsAccountId);
        if (savings == null) continue;
        // A paused account skips its whole schedule with zero interest so no
        // backlog builds up while paused.
        if (savings.isPaused) {
          await _advancePaused(savings.accountId);
          continue;
        }
        final posted = await _realize(savings, schedule);
        if (posted) credited++;
      }
      return credited;
    } finally {
      _running = false;
    }
  }

  /// Marks every unposted schedule of a paused account as realized with zero
  /// interest (no transaction), so the schedule resumes from the pause point
  /// once the account is re-enabled.
  Future<void> _advancePaused(String accountId) async {
    final schedules = await savingsDao.schedulesFor(accountId);
    for (final schedule in schedules) {
      if (schedule.transactionId == null) {
        await savingsDao.markPosted(
          schedule.id,
          transactionId: null,
          principalCents: 0,
          interestCents: 0,
        );
      }
    }
  }

  Future<bool> _realize(SavingsAccount savings, InterestSchedule schedule) async {
    final dueDate = DateTime.fromMillisecondsSinceEpoch(schedule.dueDate);
    final previous = await _previousCreditDate(savings, schedule.dueDate);
    final days = daysBetween(previous, dueDate);
    final principal =
        await ledgerDao.balance(savings.accountId, asOfMillis: schedule.dueDate);
    final interest = interestOn(
      principalCents: principal,
      annualRate: savings.interestRate,
      days: days,
    );

    if (interest <= 0 || savings.isPaused) {
      await savingsDao.markPosted(
        schedule.id,
        transactionId: null,
        principalCents: principal < 0 ? 0 : principal,
        interestCents: 0,
      );
      return false;
    }

    final account = await accountsDao.byId(savings.accountId);
    final txId = await engine.postTransaction(
      description: 'Interest credit for ${account?.name ?? savings.accountId}',
      on: dueDate,
      lines: buildLedgerLines(
        type: TxType.income,
        accountId: savings.accountId,
        amountCents: interest,
      ),
    );
    await savingsDao.markPosted(
      schedule.id,
      transactionId: txId,
      principalCents: principal,
      interestCents: interest,
    );
    return true;
  }

  /// The credit date before [dueMillis] for [savings], or the arrangement's
  /// start date when none exists. The period between the two weighs interest.
  Future<DateTime> _previousCreditDate(
    SavingsAccount savings,
    int dueMillis,
  ) async {
    final schedules = await savingsDao.schedulesFor(savings.accountId);
    DateTime? previous;
    for (final s in schedules) {
      if (s.dueDate >= dueMillis) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(s.dueDate);
      if (previous == null || date.isAfter(previous)) previous = date;
    }
    return previous ?? DateTime.fromMillisecondsSinceEpoch(savings.startDate);
  }

  static int _counter = 0;

  static String _defaultId() =>
      'sch_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
