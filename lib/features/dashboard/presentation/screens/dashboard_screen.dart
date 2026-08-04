import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/home_shell.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../transactions/domain/transaction_posting.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _startedSync = false;

  @override
  void initState() {
    super.initState();
    // Kick off an on-launch sync once the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_startedSync && mounted) {
        _startedSync = true;
        final uid = ref.read(authStateProvider).valueOrNull;
        if (uid != null) {
          ref.read(syncStateProvider.notifier).syncNow(uid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final syncState = ref.watch(syncStateProvider);
    final uid = ref.watch(authStateProvider).valueOrNull;
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? const [];
    final cashFlow = ref.watch(monthCashFlowProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => HomeShell.of(context).openDrawer(),
        ),
        title: const Text('PeraKo'),
        actions: [
          IconButton(
            onPressed: uid == null
                ? null
                : () => ref.read(syncStateProvider.notifier).syncNow(uid),
            icon: syncState.status == SyncStatus.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync now',
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _NetWorthCard(netWorthCents: data.netWorthCents),
            const SizedBox(height: 16),
            _CashFlowCard(cashFlow: cashFlow.value),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent transactions',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push('/transactions'),
                  child: const Text('See all'),
                ),
              ],
            ),
            if (data.rows.isEmpty && transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'No accounts yet.\nUse + to record your first income.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(
                  child: Text(
                    'No transactions yet.\nUse + to record one.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final row in transactions.take(5))
                _TransactionRowTile(row: row),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_dashboard',
        onPressed: () => context.push('/transactions/new'),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TransactionRowTile extends StatelessWidget {
  const _TransactionRowTile({required this.row});

  final TransactionRow row;

  static String _typeLabel(TxType type) => switch (type) {
        TxType.income => 'Income',
        TxType.expense => 'Expense',
        TxType.transfer => 'Transfer',
      };

  @override
  Widget build(BuildContext context) {
    final isInflow = row.signedAmountCents >= 0;
    return Card(
      child: ListTile(
        title: Text(row.transaction.description.isNotEmpty
            ? row.transaction.description
            : _typeLabel(row.type)),
        subtitle: Text(row.accountName),
        trailing: Text(
          '${isInflow ? '+' : '-'}${formatMoney(row.signedAmountCents.abs(), symbol: CurrencyScope.of(context))}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isInflow ? Colors.green : Theme.of(context).colorScheme.error,
          ),
        ),
        onTap: () => context.push('/transactions/${row.transaction.id}'),
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.cashFlow});

  final (int, int)? cashFlow;

  @override
  Widget build(BuildContext context) {
    final (income, expense) = cashFlow ?? (0, 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _CashFlowColumn(
                label: 'Income this month',
                amount: income,
                color: Colors.green,
              ),
            ),
            const VerticalDivider(width: 32),
            Expanded(
              child: _CashFlowColumn(
                label: 'Expenses this month',
                amount: expense,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowColumn extends StatelessWidget {
  const _CashFlowColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          formatMoney(amount, symbol: CurrencyScope.of(context)),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.netWorthCents});
  final int netWorthCents;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Worth', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              formatMoney(netWorthCents, symbol: CurrencyScope.of(context)),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
