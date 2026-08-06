import '../../../core/database/app_database.dart';
import '../../../core/database/daos/ledger_dao.dart';

/// Recurrence of a [Budgets] row.
enum BudgetPeriod {
  monthly('Monthly'),
  yearly('Yearly');

  const BudgetPeriod(this.label);

  final String label;

  static BudgetPeriod fromKey(String key) => BudgetPeriod.values.firstWhere(
        (p) => p.name == key,
        orElse: () => BudgetPeriod.monthly,
      );
}

/// An inclusive date window `[start, end]`.
class PeriodWindow {
  const PeriodWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get startMillis => start.millisecondsSinceEpoch;
  int get endMillis => end.millisecondsSinceEpoch;
}

/// Derived spending metrics for a budget's current period.
class BudgetProgress {
  const BudgetProgress({
    required this.amountCents,
    required this.spentCents,
    required this.forecastCents,
    required this.period,
    required this.periodLabel,
    required this.amountPerDayCents,
  });

  /// The budgeted amount, including any positive rollover carry.
  final int amountCents;

  final int spentCents;

  /// Projected period-end spend via linear extrapolation of the daily rate.
  final int forecastCents;

  final PeriodWindow period;

  final String periodLabel;

  /// Remaining amount divided by the days left in the period (minimum 1).
  final int amountPerDayCents;

  int get remainingCents => amountCents - spentCents;

  bool get isOver => spentCents > amountCents;

  /// spent / amount; >1.0 when over budget.
  double get ratio => amountCents <= 0 ? 0 : spentCents / amountCents;
}

/// The budget engine: resolves the current period window, measures spending
/// from the ledger, and derives progress, forecast, and rollover.
class BudgetService {
  BudgetService({required this._ledgerDao});

  final LedgerDao _ledgerDao;
  /// The period containing [now], clamped to the budget's explicit
  /// `startDate`/`endDate` bounds when present.
  PeriodWindow windowFor(Budget budget, DateTime now) {
    final start = budget.startDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(budget.startDate!);
    final end = budget.endDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(budget.endDate!);

    var wStart = _calendarStart(budget, now);
    var wEnd = _calendarEnd(budget, now);
    if (start != null && start.isAfter(wStart)) wStart = start;
    if (end != null && end.isBefore(wEnd)) wEnd = end;
    return PeriodWindow(wStart, wEnd);
  }

  DateTime _calendarStart(Budget budget, DateTime now) {
    return budget.period == 'monthly'
        ? DateTime(now.year, now.month, 1)
        : DateTime(now.year, 1, 1);
  }

  DateTime _calendarEnd(Budget budget, DateTime now) {
    final start = _calendarStart(budget, now);
    return budget.period == 'monthly'
        ? DateTime(start.year, start.month + 1, 1)
            .subtract(const Duration(milliseconds: 1))
        : DateTime(start.year + 1, 1, 1)
            .subtract(const Duration(milliseconds: 1));
  }

  /// The period immediately before [window].
  PeriodWindow previousWindow(Budget budget, PeriodWindow window) {
    final start = window.start;
    return budget.period == 'monthly'
        ? PeriodWindow(
            DateTime(start.year, start.month - 1, 1),
            DateTime(start.year, start.month, 1)
                .subtract(const Duration(milliseconds: 1)),
          )
        : PeriodWindow(
            DateTime(start.year - 1, 1, 1),
            DateTime(start.year, 1, 1)
                .subtract(const Duration(milliseconds: 1)),
          );
  }

  /// Spending within [window], scoped to the budget's category or account.
  Future<int> spentIn(Budget budget, PeriodWindow window) {
    return _ledgerDao.spentCents(
      fromMillis: window.startMillis,
      toMillis: window.endMillis,
      categoryId: budget.categoryId,
      accountId: budget.accountId,
    );
  }

  /// Spending for a single [categoryId] within [window] — used by the
  /// per-category budget limits breakdown.
  Future<int> spentForCategory(
    String categoryId,
    PeriodWindow window,
  ) {
    return _ledgerDao.spentCents(
      fromMillis: window.startMillis,
      toMillis: window.endMillis,
      categoryId: categoryId,
    );
  }

  /// The budgeted amount for the current period, plus a positive rollover
  /// carry from the previous period when [Budgets.rollover] is enabled and the
  /// budget already existed then.
  Future<int> effectiveAmount(Budget budget, DateTime now) async {
    var amount = budget.amountCents;
    if (!budget.rollover) return amount;

    final prev = previousWindow(budget, windowFor(budget, now));
    final created = DateTime.fromMillisecondsSinceEpoch(budget.createdAt);
    if (prev.end.isBefore(created)) return amount;

    final spentPrev = await spentIn(budget, prev);
    final carry = budget.amountCents - spentPrev;
    if (carry > 0) amount += carry;
    return amount;
  }

  /// Derives the full progress snapshot for [budget].
  Future<BudgetProgress> progress(Budget budget, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    final window = windowFor(budget, current);
    final amount = await effectiveAmount(budget, current);
    final spent = await spentIn(budget, window);

    final remaining = amount - spent;
    final daysElapsed =
        window.start.isAfter(current) ? 0 : current.difference(window.start).inDays + 1;
    final daysLeft = (window.end.difference(current).inDays + 1).clamp(1, 1 << 30);
    final dailyRate = daysElapsed <= 0 ? 0.0 : spent / daysElapsed;
    final forecast = spent + (dailyRate * daysLeft).round();

    return BudgetProgress(
      amountCents: amount,
      spentCents: spent,
      forecastCents: forecast,
      period: window,
      periodLabel: _periodLabel(budget, window),
      amountPerDayCents: remaining < 0 ? remaining : (remaining / daysLeft).floor(),
    );
  }

  String _periodLabel(Budget budget, PeriodWindow window) {
    final start = window.start;
    if (budget.period == 'monthly') {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[start.month - 1]} ${start.year}';
    }
    return '${start.year}';
  }
}
