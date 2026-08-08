import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/transaction_posting.dart';
import '../providers/transactions_providers.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_transactions',
        onPressed: () => context.push('/transactions/new'),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No transactions yet.\nUse + to record one.',
                  textAlign: TextAlign.center),
            );
          }

          // Group by local calendar day, preserving newest-first order.
          final groups = <DateTime, List<TransactionRow>>{};
          for (final row in list) {
            final day = _day(row.transaction.date);
            groups.putIfAbsent(day, () => []).add(row);
          }
          final days = groups.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            children: [
              for (final day in days) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    _formatDay(day),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final row in groups[day]!)
                  _TransactionTile(row: row, day: day),
              ],
            ],
          );
        },
      ),
    );
  }

  static DateTime _day(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime(d.year, d.month, d.day);
  }

  static String _formatDay(DateTime day) {
    final now = _day(DateTime.now().millisecondsSinceEpoch);
    if (day == now) return 'Today';
    final yesterday =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (day == yesterday) return 'Yesterday';
    return '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}-${day.year}';
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.row, required this.day});

  final TransactionRow row;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = row.signedAmountCents;
    final isInflow = amount >= 0;
    final typeLabel = switch (row.type) {
      TxType.income => 'Income',
      TxType.expense => 'Expense',
      TxType.transfer => 'Transfer',
    };
    final subtitle = row.type == TxType.transfer
        ? '$typeLabel · ${row.accountName} → ${row.toAccountName}'
        : '$typeLabel · ${row.accountName}'
            '${row.categoryName != null ? ' · ${row.categoryName}' : ''}';

    return Dismissible(
      key: ValueKey('tx_${row.transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Archive transaction?'),
            content: const Text(
                'The transaction will be hidden. Balances are recalculated.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Archive')),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(transactionsDaoProvider).archive(
                row.transaction.id,
                nowMillis: DateTime.now().millisecondsSinceEpoch,
              );
        }
        return false; // Row is removed reactively via the stream.
      },
      child: ListTile(
        title: Text(
            row.transaction.description.isNotEmpty
                ? row.transaction.description
                : typeLabel),
        subtitle: Text(subtitle),
        trailing: Text(
          '${isInflow ? '+' : '-'}${formatMoney(amount.abs(), symbol: CurrencyScope.of(context))}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isInflow ? Colors.green : Theme.of(context).colorScheme.error,
              ),
        ),
        onTap: () => context.push('/transactions/${row.transaction.id}'),
      ),
    );
  }
}

