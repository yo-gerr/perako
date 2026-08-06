import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/mp2_service.dart';

/// The MP2 engine, backed by the ledger.
final mp2ServiceProvider = Provider<Mp2Service>((ref) {
  return Mp2Service(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(ledgerEngineProvider),
    dao: ref.watch(mp2DaoProvider),
  );
});

/// An MP2 account paired with its account, ready for the list screen.
class Mp2Row {
  const Mp2Row({required this.mp2, required this.account});

  final Mp2Account mp2;
  final Account account;

  bool get isMatured => mp2.isMatured;

  /// Whole days until maturity; <= 0 once the term has ended.
  int daysLeft(DateTime now) =>
      _dateOnly(DateTime.fromMillisecondsSinceEpoch(mp2.maturityDate))
          .difference(_dateOnly(now))
          .inDays;

  /// True once the term has ended but the account is not yet flagged matured.
  bool isDue(DateTime now) => !isMatured && daysLeft(now) <= 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// All active MP2 accounts paired with their accounts and balances, newest
/// creation first. Emits a fresh snapshot on any MP2, account, or ledger
/// change.
final mp2AccountsProvider = StreamProvider<List<Mp2Row>>((ref) async* {
  final dao = ref.watch(mp2DaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final accounts = await dao.active();
    final allAccounts = await accountsDao.active();
    final rows = <Mp2Row>[];
    for (final mp2 in accounts) {
      final account = allAccounts.where((a) => a.id == mp2.accountId).toList();
      if (account.isEmpty) continue;
      rows.add(Mp2Row(mp2: mp2, account: account.first));
    }
    rows.sort((a, b) => b.mp2.createdAt.compareTo(a.mp2.createdAt));
    yield rows;
  }
});

/// Archived MP2 accounts paired with their accounts.
final archivedMp2AccountsProvider = StreamProvider<List<Mp2Row>>((ref) async* {
  final dao = ref.watch(mp2DaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchArchived(),
    accountsDao.watchActive(),
  ]);

  await for (final _ in trigger) {
    final accounts = await dao.archived();
    final allAccounts = await accountsDao.active();
    final rows = <Mp2Row>[];
    for (final mp2 in accounts) {
      final account = allAccounts.where((a) => a.id == mp2.accountId).toList();
      if (account.isEmpty) continue;
      rows.add(Mp2Row(mp2: mp2, account: account.first));
    }
    rows.sort((a, b) => b.mp2.createdAt.compareTo(a.mp2.createdAt));
    yield rows;
  }
});

/// Everything the detail screen renders for one MP2 account.
class Mp2DetailData {
  const Mp2DetailData({
    required this.row,
    required this.balanceCents,
    required this.forecast,
    required this.maturityValueCents,
  });

  final Mp2Row row;
  final int balanceCents;

  /// Remaining unrealized dividend years, earliest first.
  final List<Mp2DividendForecast> forecast;

  /// Projected balance at the end of the 5-year term.
  final int maturityValueCents;

  Mp2Account get mp2 => row.mp2;
  Account get account => row.account;
}

/// Full detail snapshot for one MP2 account, recomputed on any MP2,
/// contribution, withdrawal, dividend, account, or ledger change.
final mp2DetailProvider =
    StreamProvider.family<Mp2DetailData?, String>((ref, id) async* {
  final dao = ref.watch(mp2DaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final service = ref.watch(mp2ServiceProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    dao.watchContributionsFor(id),
    dao.watchWithdrawalsFor(id),
    dao.watchDividendsFor(id),
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final mp2 = await dao.byId(id);
    if (mp2 == null || mp2.deletedAt != null) {
      yield null;
      continue;
    }
    final account = await accountsDao.byId(mp2.accountId);
    if (account == null) {
      yield null;
      continue;
    }
    final balance = await service.engine.getBalance(mp2.accountId);
    final forecast = await service.forecastAnnualDividends(mp2);
    final maturityValue = await service.forecastMaturityValue(mp2);
    yield Mp2DetailData(
      row: Mp2Row(mp2: mp2, account: account),
      balanceCents: balance,
      forecast: forecast,
      maturityValueCents: maturityValue,
    );
  }
});

/// Realized dividend rows for one MP2 account, oldest first.
final mp2DividendsProvider =
    StreamProvider.family<List<Mp2Dividend>, String>((ref, id) {
  return ref.watch(mp2DaoProvider).watchDividendsFor(id);
});

/// Display label helper shared by the MP2 screens.
String mp2Title(Mp2Row row) {
  final label = row.mp2.label.trim();
  if (label.isNotEmpty) return label;
  return row.account.name;
}
