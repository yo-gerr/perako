import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../../domain/bill_service.dart';
import '../providers/bills_providers.dart';

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(billDetailProvider(billId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.bill.name ?? 'Bill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit bill',
            onPressed: () => context.push('/bills/$billId/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Bill not found.'));
          }
          return _BillDetailBody(data: data, billId: billId);
        },
      ),
    );
  }
}

class _BillDetailBody extends ConsumerWidget {
  const _BillDetailBody({required this.data, required this.billId});

  final BillDetailData data;
  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final bill = data.bill;
    final due = DateTime.fromMillisecondsSinceEpoch(bill.nextDueDate);

    final accounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[]);
    final categories =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[]);
    final account = accounts.where((a) => a.id == bill.accountId).toList();
    final category =
        categories.where((c) => c.id == bill.categoryId).toList();
    final accountName = account.isEmpty ? null : account.first.name;
    final categoryName = category.isEmpty ? null : category.first.name;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  formatMoney(bill.amountCents, symbol: symbol),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Frequency',
                    value: BillFrequency.fromKey(bill.frequency).label),
                _InfoRow(label: 'Next due',
                    value: '${due.month}/${due.day}/${due.year}'),
                if (accountName != null)
                  _InfoRow(label: 'Account', value: accountName),
                if (categoryName != null)
                  _InfoRow(label: 'Category', value: categoryName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _payNow(context, ref),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Pay now'),
        ),
        const SizedBox(height: 16),
        Text('Payment history', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (data.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No payments yet. Payments are recorded as ledger expenses.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final p in data.payments)
            _PaymentTile(payment: p, symbol: symbol),
      ],
    );
  }

  Future<void> _payNow(BuildContext context, WidgetRef ref) async {
    final bill = data.bill;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pay bill?'),
        content: Text(
            'Post ${formatMoney(bill.amountCents)} for "${bill.name}" as an expense?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pay')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(billServiceProvider).payBill(bill);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${bill.name} paid.')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.symbol});

  final BillPayment payment;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = DateTime.fromMillisecondsSinceEpoch(payment.paidOn);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle_outline),
        title: Text(
          '${on.month}/${on.day}/${on.year}',
          style: theme.textTheme.bodyMedium,
        ),
        trailing: Text(
          formatMoney(payment.amountCents, symbol: symbol),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
