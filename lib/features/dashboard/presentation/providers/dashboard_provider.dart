import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/accounts_dao.dart';
import '../../../../core/database/daos/ledger_dao.dart';
import '../../../../core/providers/core_providers.dart';

/// A single account paired with its currently derived balance (cents).
class BalanceRow {
  const BalanceRow(this.account, this.balanceCents);

  final Account account;
  final int balanceCents;
}

/// A snapshot of what the dashboard shows: every active account with its
/// derived balance, and the total net worth.
class DashboardData {
  const DashboardData({required this.rows, required this.netWorthCents});

  final List<BalanceRow> rows;
  final int netWorthCents;
}

/// Reactively assembles the dashboard from the ledger. Emits a fresh snapshot
/// whenever an account or a ledger entry changes.
final dashboardProvider = StreamProvider<DashboardData>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final engine = ref.watch(ledgerEngineProvider);
  final accountsDao = AccountsDao(db);
  final ledgerDao = LedgerDao(db);

  final trigger = StreamGroup.merge<Object?>([
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final activeAccounts = await accountsDao.active();
    final rows = <BalanceRow>[];
    for (final a in activeAccounts) {
      final balance = await engine.getBalance(a.id);
      rows.add(BalanceRow(a, balance));
    }
    final netWorth = await engine.getNetWorth();
    yield DashboardData(rows: rows, netWorthCents: netWorth);
  }
});