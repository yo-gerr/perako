import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/savings_forecast_service.dart';
import '../../domain/savings_interest_service.dart';

/// The savings engine, backed by the ledger.
final savingsInterestServiceProvider = Provider<SavingsInterestService>((ref) {
  return SavingsInterestService(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(ledgerEngineProvider),
    savingsDao: ref.watch(savingsDaoProvider),
    ledgerDao: ref.watch(ledgerDaoProvider),
    accountsDao: ref.watch(accountsDaoProvider),
  );
});

/// Pure balance-projection helper.
final savingsForecastServiceProvider = Provider<SavingsForecastService>(
  (ref) => SavingsForecastService(),
);

/// The savings configuration for a single account, or null when the account
/// has not been set up as an interest-bearing savings account.
final savingsAccountProvider =
    StreamProvider.family<SavingsAccount?, String>((ref, accountId) async* {
  final dao = ref.watch(savingsDaoProvider);
  await for (final rows in dao.watchActive()) {
    final matches = rows.where((s) => s.accountId == accountId).toList();
    yield matches.isEmpty ? null : matches.first;
  }
});

/// Everything the savings detail screen renders.
class SavingsDetailData {
  const SavingsDetailData({
    required this.savings,
    required this.account,
    required this.balanceCents,
    required this.schedules,
  });

  final SavingsAccount? savings;
  final Account account;
  final int balanceCents;

  /// Planned and realized interest credits, newest due date first.
  final List<InterestSchedule> schedules;
}

/// Full snapshot for a single savings account, recomputed on any savings,
/// schedule, or ledger change.
final savingsDetailProvider =
    StreamProvider.family<SavingsDetailData?, String>((ref, accountId) async* {
  final dao = ref.watch(savingsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final engine = ref.watch(ledgerEngineProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    dao.watchSchedulesFor(accountId),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final account = await accountsDao.byId(accountId);
    if (account == null) {
      yield null;
      continue;
    }
    final savings = await dao.byAccountId(accountId);
    final balanceCents = await engine.getBalance(accountId);
    final schedules = await dao.schedulesFor(accountId);
    schedules.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    yield SavingsDetailData(
      savings: savings,
      account: account,
      balanceCents: balanceCents,
      schedules: schedules,
    );
  }
});

/// Projected month-end balances for a savings account, recomputed on savings
/// or ledger changes. Empty while the account is not configured or paused.
final savingsForecastProvider =
    StreamProvider.family<List<ForecastPoint>, String>((ref, accountId) async* {
  final dao = ref.watch(savingsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final engine = ref.watch(ledgerEngineProvider);
  final service = ref.watch(savingsForecastServiceProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final savings = await dao.byAccountId(accountId);
    if (savings == null || savings.isPaused) {
      yield const [];
      continue;
    }
    final balance = await engine.getBalance(accountId);
    yield service.forecast(
      principalCents: balance,
      annualRate: savings.interestRate,
      frequency: CompoundingFrequency.fromKey(savings.compoundingFrequency),
    );
  }
});
