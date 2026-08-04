import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../providers/transactions_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionProvider(transactionId));
    final entries = ref.watch(transactionEntriesProvider(transactionId));
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final categoryNames = {for (final c in categories) c.id: c.name};

    return transaction.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (tx) {
        if (tx == null) {
          return const Scaffold(
              body: Center(child: Text('Transaction not found')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(tx.description.isEmpty ? 'Transaction' : tx.description),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () => context.push('/transactions/$transactionId/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Reverse',
                onPressed: () => _confirmReverse(context, ref),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(tx.date)
                            .toLocal()
                            .toString()
                            .split(' ')[0],
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(tx.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ledger entries', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              entries.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (list) => Column(
                  children: [
                    for (final e in list)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                              accountNames[e.accountId] ?? e.accountId),
                          subtitle: Text(
                            '${e.type == 'debit' ? 'Debit' : 'Credit'}'
                            '${e.categoryId != null && categoryNames.containsKey(e.categoryId) ? ' · ${categoryNames[e.categoryId]}' : ''}',
                          ),
                          trailing: Text(
                            '${e.type == 'debit' ? '+' : '-'}${formatMoney(e.amount, symbol: CurrencyScope.of(context))}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReverse(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reverse transaction?'),
        content: const Text(
            'A reversal is posted, keeping the original for the audit trail. '
            'Balances are restored.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reverse')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(ledgerEngineProvider).reverseTransaction(transactionId);
      if (context.mounted) context.pop();
    }
  }
}
