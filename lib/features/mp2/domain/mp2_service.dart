import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/mp2_dao.dart';
import '../../ledger/domain/ledger_engine.dart';
import '../../transactions/domain/transaction_posting.dart';

/// A projected annual dividend for one remaining year of an MP2 term.
class Mp2DividendForecast {
  const Mp2DividendForecast({
    required this.yearNumber,
    required this.anniversary,
    required this.dividendCents,
    required this.balanceAfterCents,
  });

  /// 1-based year of the term (1 = first year).
  final int yearNumber;

  /// Date the dividend is credited.
  final DateTime anniversary;

  final int dividendCents;

  /// Projected balance after this dividend is added.
  final int balanceAfterCents;
}

/// The MP2 engine: manages 5-year Pag-IBIG MP2 accounts, moves contributions
/// and withdrawals through the ledger, realizes annual dividends as balanced
/// income postings, and forecasts future dividends and the maturity value.
class Mp2Service {
  Mp2Service({
    required this.db,
    required this.engine,
    required this.dao,
    String Function()? idGenerator,
    int Function()? clock,
  })  : _idGen = idGenerator ?? _defaultId,
        _clock = clock ?? _defaultClock;

  /// An MP2 term is five years by program rules.
  static const int termYears = 5;

  final AppDatabase db;
  final LedgerEngine engine;
  final Mp2Dao dao;

  final String Function() _idGen;
  final int Function() _clock;

  /// The maturity date of an MP2 account starting at [startDate].
  static DateTime maturityDateFor(DateTime startDate) =>
      DateTime(startDate.year + termYears, startDate.month, startDate.day);

  /// The annual dividend for a dividend year in integer cents, approximating
  /// MP2's average-daily-balance method: contributions arrive halfway through
  /// the year on average, so they earn half a year's dividend.
  static int annualDividend({
    required int openingBalanceCents,
    required int contributionsInYearCents,
    required double dividendRate,
  }) {
    if (dividendRate <= 0) return 0;
    return ((openingBalanceCents + contributionsInYearCents / 2) * dividendRate)
        .round();
  }

  /// Creates an MP2 account with a 5-year term on [accountId]. Nothing moves
  /// through the ledger until the first contribution.
  Future<Mp2Account> create({
    required String accountId,
    required String label,
    required double dividendRate,
    required DateTime startDate,
  }) async {
    final now = _clock();
    return dao.insert(Mp2AccountsCompanion(
      id: Value(_idGen()),
      accountId: Value(accountId),
      label: Value(label),
      dividendRate: Value(dividendRate),
      startDate: Value(startDate.millisecondsSinceEpoch),
      maturityDate: Value(maturityDateFor(startDate).millisecondsSinceEpoch),
      isMatured: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
      version: const Value(1),
    ));
  }

  /// Updates an unmatured account, re-deriving the maturity date from the new
  /// start date.
  Future<void> update(
    Mp2Account mp2, {
    required String label,
    required double dividendRate,
    required DateTime startDate,
  }) async {
    await dao.updateEntry(Mp2AccountsCompanion(
      id: Value(mp2.id),
      label: Value(label),
      dividendRate: Value(dividendRate),
      startDate: Value(startDate.millisecondsSinceEpoch),
      maturityDate: Value(maturityDateFor(startDate).millisecondsSinceEpoch),
      updatedAt: Value(_clock()),
    ));
  }

  /// Contributes [amountCents] to [mp2] from [sourceAccountId]: posts a
  /// balanced transfer into the MP2 account and records a contribution row.
  /// Returns the id of the generated transaction.
  Future<String> contribute(
    Mp2Account mp2, {
    required String sourceAccountId,
    required int amountCents,
    DateTime? on,
    String? note,
  }) async {
    assert(
      sourceAccountId != mp2.accountId,
      'Source and MP2 account must differ',
    );
    final contributedOn = on ?? DateTime.now();
    final transactionId = await engine.postTransaction(
      description: 'MP2 contribution — ${mp2.label}',
      on: contributedOn,
      notes: note,
      lines: buildLedgerLines(
        type: TxType.transfer,
        accountId: sourceAccountId,
        toAccountId: mp2.accountId,
        amountCents: amountCents,
      ),
    );
    await dao.insertContribution(Mp2ContributionsCompanion(
      id: Value(_idGen()),
      mp2AccountId: Value(mp2.id),
      transactionId: Value(transactionId),
      amountCents: Value(amountCents),
      contributedOn: Value(contributedOn.millisecondsSinceEpoch),
      note: Value(note),
      createdAt: Value(_clock()),
    ));
    return transactionId;
  }

  /// Withdraws [amountCents] from [mp2] to [toAccountId]: posts a balanced
  /// transfer out of the MP2 account and records a withdrawal row. Returns the
  /// id of the generated transaction.
  Future<String> withdraw(
    Mp2Account mp2, {
    required String toAccountId,
    required int amountCents,
    DateTime? on,
    String? note,
  }) async {
    assert(
      toAccountId != mp2.accountId,
      'Destination and MP2 account must differ',
    );
    final withdrawnOn = on ?? DateTime.now();
    final transactionId = await engine.postTransaction(
      description: 'MP2 withdrawal — ${mp2.label}',
      on: withdrawnOn,
      notes: note,
      lines: buildLedgerLines(
        type: TxType.transfer,
        accountId: mp2.accountId,
        toAccountId: toAccountId,
        amountCents: amountCents,
      ),
    );
    await dao.insertWithdrawal(Mp2WithdrawalsCompanion(
      id: Value(_idGen()),
      mp2AccountId: Value(mp2.id),
      transactionId: Value(transactionId),
      amountCents: Value(amountCents),
      withdrawnOn: Value(withdrawnOn.millisecondsSinceEpoch),
      note: Value(note),
      createdAt: Value(_clock()),
    ));
    return transactionId;
  }

  /// Realizes every annual dividend that has reached [now] (defaults to the
  /// current time): posts the dividend as an income transaction dated on the
  /// year's anniversary and records a dividend row so it is never credited
  /// twice.
  ///
  /// The dividend for a year is computed on the ledger balance at the start of
  /// that year plus half of the contributions made during it. Years after the
  /// 5-year term are never credited. Returns the number of dividends posted.
  Future<int> processDividends({DateTime? now}) async {
    final asOf = now ?? DateTime.now();
    final accounts = await dao.active();
    var processed = 0;
    for (final mp2 in accounts) {
      final start = _dateOnly(DateTime.fromMillisecondsSinceEpoch(mp2.startDate));
      final maturity = _dateOnly(
          DateTime.fromMillisecondsSinceEpoch(mp2.maturityDate));
      final realized = await dao.realizedDividendYears(mp2.id);

      for (var year = 0; year < termYears; year++) {
        final yearStart = DateTime(start.year + year, start.month, start.day);
        final anniversary =
            DateTime(start.year + year + 1, start.month, start.day);
        // Never beyond the term, never in the future.
        if (anniversary.isAfter(maturity) || anniversary.isAfter(_dateOnly(asOf))) {
          break;
        }
        if (realized.contains(year)) continue;

        final openingBalanceCents = await engine.getBalance(
          mp2.accountId,
          asOf: yearStart,
        );
        final contributions = await dao.contributionsBetween(
          mp2.id,
          fromMillis: yearStart.millisecondsSinceEpoch,
          toMillis: anniversary.millisecondsSinceEpoch,
        );
        final contributionsInYear =
            contributions.fold<int>(0, (sum, c) => sum + c.amountCents);
        final dividend = annualDividend(
          openingBalanceCents: openingBalanceCents,
          contributionsInYearCents: contributionsInYear,
          dividendRate: mp2.dividendRate,
        );

        String? transactionId;
        if (dividend > 0) {
          transactionId = await engine.postTransaction(
            description: 'MP2 dividend year ${year + 1} — ${mp2.label}',
            on: anniversary,
            lines: buildLedgerLines(
              type: TxType.income,
              accountId: mp2.accountId,
              amountCents: dividend,
            ),
          );
        }
        await dao.insertDividend(Mp2DividendsCompanion(
          id: Value(_idGen()),
          mp2AccountId: Value(mp2.id),
          transactionId: Value(transactionId),
          year: Value(year),
          amountCents: Value(dividend),
          paidOn: Value(anniversary.millisecondsSinceEpoch),
          createdAt: Value(_clock()),
        ));
        processed++;
      }
    }
    return processed;
  }

  /// Marks every account whose 5-year term has ended as matured. Returns the
  /// number newly matured.
  Future<int> processMaturities({DateTime? now}) async {
    final asOf = now ?? DateTime.now();
    final accounts = await dao.active();
    var processed = 0;
    for (final mp2 in accounts) {
      final maturity =
          DateTime.fromMillisecondsSinceEpoch(mp2.maturityDate);
      if (!mp2.isMatured && !maturity.isAfter(asOf)) {
        await dao.updateEntry(Mp2AccountsCompanion(
          id: Value(mp2.id),
          isMatured: const Value(true),
          updatedAt: Value(_clock()),
        ));
        processed++;
      }
    }
    return processed;
  }

  /// Projected annual dividends for the remaining unrealized years of [mp2],
  /// compounding the current ledger balance at [Mp2Accounts.dividendRate]
  /// assuming no further contributions. Every dividend year of the 5-year term
  /// that has not been realized yet is included, so a matured account with all
  /// dividends credited returns an empty list.
  Future<List<Mp2DividendForecast>> forecastAnnualDividends(
    Mp2Account mp2, {
    DateTime? now,
  }) async {
    final start = _dateOnly(DateTime.fromMillisecondsSinceEpoch(mp2.startDate));
    final maturity =
        _dateOnly(DateTime.fromMillisecondsSinceEpoch(mp2.maturityDate));
    final realized = await dao.realizedDividendYears(mp2.id);

    var balance = await engine.getBalance(mp2.accountId);
    final forecasts = <Mp2DividendForecast>[];
    for (var year = 0; year < termYears; year++) {
      final anniversary = DateTime(start.year + year + 1, start.month, start.day);
      if (anniversary.isAfter(maturity)) break;
      if (realized.contains(year)) continue;
      final dividend = (balance * mp2.dividendRate).round();
      balance += dividend;
      forecasts.add(Mp2DividendForecast(
        yearNumber: year + 1,
        anniversary: anniversary,
        dividendCents: dividend,
        balanceAfterCents: balance,
      ));
    }
    return forecasts;
  }

  /// Projected balance at maturity: the current ledger balance grown through
  /// every remaining dividend year at [Mp2Accounts.dividendRate].
  Future<int> forecastMaturityValue(Mp2Account mp2, {DateTime? now}) async {
    final forecasts = await forecastAnnualDividends(mp2, now: now);
    if (forecasts.isEmpty) return engine.getBalance(mp2.accountId);
    return forecasts.last.balanceAfterCents;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _counter = 0;

  static String _defaultId() =>
      'mp2_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;
}
