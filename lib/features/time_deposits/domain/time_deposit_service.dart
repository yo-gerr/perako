import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/time_deposits_dao.dart';
import '../../ledger/domain/ledger_engine.dart';
import '../../transactions/domain/transaction_posting.dart';

/// How a time deposit pays interest over its fixed term.
enum InterestMethod {
  simple('Simple'),
  compound('Compounding');

  const InterestMethod(this.label);

  final String label;

  static InterestMethod fromKey(String key) => InterestMethod.values.firstWhere(
        (m) => m.name == key,
        orElse: () => InterestMethod.simple,
      );
}

/// The time deposit engine: creates and edits deposits, computes maturity
/// values, and realizes matured deposits as balanced income postings.
///
/// The principal stays in the linked account for the whole term; at maturity
/// only the interest earned is credited, dated on the maturity date.
class TimeDepositService {
  TimeDepositService({
    required this.db,
    required this.engine,
    required this.dao,
    String Function()? idGenerator,
    int Function()? clock,
  })  : _idGen = idGenerator ?? _defaultId,
        _clock = clock ?? _defaultClock;

  final AppDatabase db;
  final LedgerEngine engine;
  final TimeDepositsDao dao;

  final String Function() _idGen;
  final int Function() _clock;

  /// Whole days from [start] to [maturity] (both normalized to their calendar
  /// dates), the interest-bearing term of a deposit.
  static int daysBetween(DateTime start, DateTime maturity) =>
      _dateOnly(maturity).difference(_dateOnly(start)).inDays;

  /// Simple interest in integer cents on [principalCents] at [annualRate] (a
  /// decimal, e.g. 0.06 for 6% p.a.) for [days] using a 365-day year.
  static int interestOn({
    required int principalCents,
    required double annualRate,
    required int days,
  }) {
    if (principalCents <= 0 || days <= 0) return 0;
    return (principalCents * annualRate * days / 365).round();
  }

  /// The payout at maturity: principal plus interest. [InterestMethod.simple]
  /// adds simple interest over the term; [InterestMethod.compound] compounds
  /// daily. Non-positive terms return the principal unchanged.
  static int maturityValue({
    required int principalCents,
    required double annualRate,
    required int days,
    required InterestMethod method,
  }) {
    if (days <= 0 || principalCents <= 0) return principalCents;
    switch (method) {
      case InterestMethod.simple:
        return principalCents +
            interestOn(
              principalCents: principalCents,
              annualRate: annualRate,
              days: days,
            );
      case InterestMethod.compound:
        return (principalCents * math.pow(1 + annualRate / 365, days)).round();
    }
  }

  /// Creates a deposit on [accountId]. The principal is already held by the
  /// account; nothing is moved through the ledger until maturity.
  Future<TimeDeposit> create({
    required String accountId,
    required String label,
    required int principalCents,
    required double annualRate,
    required InterestMethod method,
    required DateTime start,
    required DateTime maturity,
  }) async {
    final now = _clock();
    return dao.insert(TimeDepositsCompanion(
      id: Value(_idGen()),
      accountId: Value(accountId),
      label: Value(label),
      principalCents: Value(principalCents),
      interestRate: Value(annualRate),
      interestMethod: Value(method.name),
      startDate: Value(start.millisecondsSinceEpoch),
      maturityDate: Value(maturity.millisecondsSinceEpoch),
      maturityValueCents: Value(
        maturityValue(
          principalCents: principalCents,
          annualRate: annualRate,
          days: daysBetween(start, maturity),
          method: method,
        ),
      ),
      isMatured: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
      version: const Value(1),
    ));
  }

  /// Updates an unmatured deposit, recomputing the projected maturity value.
  Future<void> update(
    TimeDeposit deposit, {
    required String label,
    required int principalCents,
    required double annualRate,
    required InterestMethod method,
    required DateTime start,
    required DateTime maturity,
  }) async {
    await dao.updateEntry(TimeDepositsCompanion(
      id: Value(deposit.id),
      label: Value(label),
      principalCents: Value(principalCents),
      interestRate: Value(annualRate),
      interestMethod: Value(method.name),
      startDate: Value(start.millisecondsSinceEpoch),
      maturityDate: Value(maturity.millisecondsSinceEpoch),
      maturityValueCents: Value(
        maturityValue(
          principalCents: principalCents,
          annualRate: annualRate,
          days: daysBetween(start, maturity),
          method: method,
        ),
      ),
      updatedAt: Value(_clock()),
    ));
  }

  /// Realizes every active deposit that has reached [now] (defaults to the
  /// current time): posts the interest earned as an income transaction dated
  /// on the maturity date and marks the deposit matured.
  ///
  /// Idempotent — matured deposits are skipped. Deposits that earned nothing
  /// are marked matured without a posting. Returns the number processed.
  Future<int> processMaturities({DateTime? now}) async {
    final asOf = now ?? DateTime.now();
    final due = await dao.dueToMature(asOf.millisecondsSinceEpoch);
    var processed = 0;
    for (final deposit in due) {
      final interest = deposit.maturityValueCents - deposit.principalCents;
      String? transactionId;
      if (interest > 0) {
        transactionId = await engine.postTransaction(
          description: 'Time deposit matured — ${deposit.label}',
          on: DateTime.fromMillisecondsSinceEpoch(deposit.maturityDate),
          lines: buildLedgerLines(
            type: TxType.income,
            accountId: deposit.accountId,
            amountCents: interest,
          ),
        );
      }
      await dao.markMatured(
        deposit.id,
        maturedTransactionId: transactionId,
        maturityValueCents: deposit.maturityValueCents,
        nowMillis: _clock(),
      );
      processed++;
    }
    return processed;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _counter = 0;

  static String _defaultId() =>
      'td_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;
}
