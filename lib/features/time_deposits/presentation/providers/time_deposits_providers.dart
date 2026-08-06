import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/time_deposit_service.dart';

/// The time deposit engine, backed by the ledger.
final timeDepositServiceProvider = Provider<TimeDepositService>((ref) {
  return TimeDepositService(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(ledgerEngineProvider),
    dao: ref.watch(timeDepositsDaoProvider),
  );
});

/// A deposit paired with its account, ready for the list and detail screens.
class TimeDepositRow {
  const TimeDepositRow({required this.deposit, required this.account});

  final TimeDeposit deposit;
  final Account account;

  bool get isMatured => deposit.isMatured;

  int get interestCents => deposit.maturityValueCents - deposit.principalCents;

  /// Whole days until maturity; <= 0 once the maturity date has arrived.
  int daysLeft(DateTime now) =>
      _dateOnly(DateTime.fromMillisecondsSinceEpoch(deposit.maturityDate))
          .difference(_dateOnly(now))
          .inDays;

  /// True once the maturity date has arrived but interest is still unpaid.
  bool isDue(DateTime now) => !isMatured && daysLeft(now) <= 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// All active deposits paired with their accounts, newest creation first.
/// Emits a fresh snapshot whenever a deposit, account, or ledger entry
/// changes.
final timeDepositsWithAccountsProvider =
    StreamProvider<List<TimeDepositRow>>((ref) async* {
  final dao = ref.watch(timeDepositsDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final deposits = await dao.active();
    final accounts = await accountsDao.active();
    final rows = <TimeDepositRow>[];
    for (final d in deposits) {
      final account = accounts.where((a) => a.id == d.accountId).toList();
      if (account.isEmpty) continue;
      rows.add(TimeDepositRow(deposit: d, account: account.first));
    }
    rows.sort((a, b) => b.deposit.createdAt.compareTo(a.deposit.createdAt));
    yield rows;
  }
});

/// Archived deposits paired with their accounts.
final archivedTimeDepositsProvider =
    StreamProvider<List<TimeDepositRow>>((ref) async* {
  final dao = ref.watch(timeDepositsDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchArchived(),
    accountsDao.watchActive(),
  ]);

  await for (final _ in trigger) {
    final deposits = await dao.archived();
    final accounts = await accountsDao.active();
    final rows = <TimeDepositRow>[];
    for (final d in deposits) {
      final account = accounts.where((a) => a.id == d.accountId).toList();
      if (account.isEmpty) continue;
      rows.add(TimeDepositRow(deposit: d, account: account.first));
    }
    rows.sort((a, b) => b.deposit.createdAt.compareTo(a.deposit.createdAt));
    yield rows;
  }
});

/// Everything the detail screen renders for one deposit.
class TimeDepositDetailData {
  const TimeDepositDetailData({required this.row});

  final TimeDepositRow row;

  TimeDeposit get deposit => row.deposit;
  Account get account => row.account;
}

/// Full detail snapshot for a single deposit, recomputed on any deposit,
/// account, or ledger change.
final timeDepositDetailProvider =
    StreamProvider.family<TimeDepositDetailData?, String>((ref, id) async* {
  final dao = ref.watch(timeDepositsDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final deposit = await dao.byId(id);
    if (deposit == null || deposit.deletedAt != null) {
      yield null;
      continue;
    }
    final account = await accountsDao.byId(deposit.accountId);
    if (account == null) {
      yield null;
      continue;
    }
    yield TimeDepositDetailData(row: TimeDepositRow(deposit: deposit, account: account));
  }
});

/// Active deposits that are due but unpaid, for the list banner.
final dueTimeDepositsProvider = Provider<List<TimeDepositRow>>((ref) {
  final rows = ref.watch(timeDepositsWithAccountsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return rows.where((r) => r.isDue(now)).toList();
});

/// Formatted label helper shared by the list and detail screens.
String depositTitle(TimeDepositRow row) {
  final label = row.deposit.label.trim();
  if (label.isNotEmpty) return label;
  return row.account.name;
}
