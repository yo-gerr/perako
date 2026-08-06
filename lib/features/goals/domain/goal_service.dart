import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/goals_dao.dart';
import '../../ledger/domain/ledger_engine.dart';
import '../../transactions/domain/transaction_posting.dart';

/// The kind of financial target a [Goals] row tracks.
enum GoalType {
  savings('Savings'),
  debtPayoff('Debt payoff'),
  investment('Investment');

  const GoalType(this.label);

  final String label;

  static GoalType fromKey(String key) => GoalType.values.firstWhere(
        (t) => t.name == key,
        orElse: () => GoalType.savings,
      );
}

/// Derived progress for a [Goals] row as of a point in time.
class GoalProgress {
  const GoalProgress({
    required this.currentCents,
    required this.targetCents,
    required this.daysElapsed,
    required this.daysLeft,
  });

  final int currentCents;
  final int targetCents;

  /// Whole days since the goal was created.
  final int daysElapsed;

  /// Whole days until the target date (or the default horizon when the goal
  /// has no target date).
  final int daysLeft;

  double get ratio => targetCents <= 0 ? 0 : currentCents / targetCents;

  int get remainingCents => targetCents - currentCents;

  bool get isComplete => currentCents >= targetCents;
}

/// The goal engine: posts contributions as balanced ledger transfers and
/// derives progress, completion forecasts, and contribution suggestions.
class GoalService {
  GoalService({
    required this._db,
    required this._engine,
    required this._goalsDao,
  });

  final AppDatabase _db;
  final LedgerEngine _engine;
  final GoalsDao _goalsDao;

  /// Fallback horizon for a goal without an explicit target date.
  static const int _defaultHorizonDays = 365;

  /// Contributes [amountCents] to [goal] from [sourceAccountId]: posts a
  /// balanced transfer into the goal's funding account through the ledger,
  /// records a [GoalContributions] row linking the posting, and bumps the
  /// goal's current amount (completing it once the target is reached) — all in
  /// one transaction.
  ///
  /// Returns the id of the generated transaction.
  Future<String> contribute(
    Goal goal, {
    required String sourceAccountId,
    required int amountCents,
    DateTime? on,
    String? note,
  }) async {
    assert(
      sourceAccountId != goal.fundingAccountId,
      'Source and funding account must differ',
    );
    final contributedOn = on ?? DateTime.now();
    final txId = await _db.transaction(() async {
      // Re-read the stored amount so repeated contributions from a stale
      // [Goal] still accumulate correctly.
      final stored = await _goalsDao.byId(goal.id);
      final current = stored?.currentAmountCents ?? goal.currentAmountCents;
      final id = await _engine.postTransaction(
        description: 'Contribution to ${goal.name}',
        on: contributedOn,
        notes: note,
        lines: buildLedgerLines(
          type: TxType.transfer,
          accountId: sourceAccountId,
          toAccountId: goal.fundingAccountId,
          amountCents: amountCents,
        ),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await _goalsDao.insertContribution(GoalContributionsCompanion(
        id: Value(_nextId()),
        goalId: Value(goal.id),
        transactionId: Value(id),
        amountCents: Value(amountCents),
        contributedOn: Value(contributedOn.millisecondsSinceEpoch),
        note: Value(note),
        createdAt: Value(now),
      ));
      final updated = current + amountCents;
      await _goalsDao.updateGoal(GoalsCompanion(
        id: Value(goal.id),
        currentAmountCents: Value(updated),
        isCompleted: Value(updated >= goal.targetAmountCents),
        updatedAt: Value(now),
      ));
      return id;
    });
    return txId;
  }

  /// Progress of [goal] as of [now] (defaults to the current time).
  GoalProgress progress(Goal goal, {DateTime? now}) {
    final asOf = now ?? DateTime.now();
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(goal.createdAt);
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final daysElapsed = today.difference(start).inDays;

    final targetDate = goal.targetDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(goal.targetDate!);
    final horizon = targetDate == null
        ? start.add(const Duration(days: _defaultHorizonDays))
        : DateTime(targetDate.year, targetDate.month, targetDate.day);
    final daysLeft = horizon.difference(today).inDays;

    return GoalProgress(
      currentCents: goal.currentAmountCents,
      targetCents: goal.targetAmountCents,
      daysElapsed: daysElapsed,
      daysLeft: daysLeft,
    );
  }

  /// Estimated completion date given the average contribution rate since the
  /// goal was created. Null when the goal is already complete or has made no
  /// progress yet.
  DateTime? forecastCompletion(Goal goal, {DateTime? now}) {
    final asOf = now ?? DateTime.now();
    final p = progress(goal, now: asOf);
    if (p.isComplete || p.currentCents <= 0) return null;
    final ratePerDay = p.currentCents / (p.daysElapsed + 1);
    final daysNeeded = (p.remainingCents / ratePerDay).ceil();
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    return today.add(Duration(days: daysNeeded));
  }

  /// The monthly contribution needed to hit the target by the target date
  /// (defaulting to a 12-month horizon when no target date is set). Zero when
  /// nothing more is needed.
  int suggestedMonthlyContribution(Goal goal, {DateTime? now}) {
    final p = progress(goal, now: now);
    if (p.isComplete || p.remainingCents <= 0) return 0;
    final monthsLeft = (p.daysLeft + 1) / 30.44;
    final months = monthsLeft < 1 ? 1 : monthsLeft;
    return (p.remainingCents / months).ceil();
  }

  static int _counter = 0;

  static String _nextId() =>
      'con_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}
