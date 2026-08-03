import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../ledger/domain/ledger_engine.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
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

    return Scaffold(
      appBar: AppBar(
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
          IconButton(
            onPressed: () => _openTransactionDialog(context),
            icon: const Icon(Icons.add),
            tooltip: 'Add income',
          ),
          IconButton(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
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
            if (data.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'No accounts yet.\nUse + to record your first income.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...data.rows.map(
                (row) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(row.account.name),
                    subtitle: Text('${row.account.type} · ${row.account.currency}',
),
                    trailing: Text(
                      formatMoney(row.balanceCents),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Local data will be cleared. Your data is kept in the cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  Future<void> _openTransactionDialog(BuildContext context) async {
    final ref = this.ref;
    await showDialog<void>(
      context: context,
      builder: (_) => _AddIncomeDialog(ref: ref),
    );
  }
}

class _AddIncomeDialog extends ConsumerStatefulWidget {
  const _AddIncomeDialog({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends ConsumerState<_AddIncomeDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final pesos = int.tryParse(_amount.text.trim());
    if (name.isEmpty || pesos == null || pesos <= 0) return;

    final dao = widget.ref.read(accountsDaoProvider);
    final engine = widget.ref.read(ledgerEngineProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'acc_$now';

    // Create the account if it does not exist yet.
    if (await dao.byId(id) == null) {
      await dao.insertAccount(AccountsCompanion(
        id: Value(id),
        name: Value(name),
        type: const Value('checking'),
        currency: const Value('PHP'),
        color: const Value('teal'),
        icon: const Value('wallet'),
        isArchived: const Value(false),
        openingDate: Value(now),
        updatedAt: Value(now),
        version: const Value(1),
      ));
    }

    // Record income: debit the account, credit an 'income' counterparty so
    // the ledger stays balanced.
    await engine.postTransaction(
      description: 'Income: $name',
      lines: [
        LedgerLine(accountId: id, type: EntryType.debit, amountCents: pesos * 100),
        LedgerLine(accountId: 'counterparty_income', type: EntryType.credit, amountCents: pesos * 100),
      ],
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add income'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Account name'),
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (₱)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
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
              formatMoney(netWorthCents),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}