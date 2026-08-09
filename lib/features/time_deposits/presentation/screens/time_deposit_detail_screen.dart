import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/perako_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/time_deposit_service.dart';
import '../providers/time_deposits_providers.dart';

class TimeDepositDetailScreen extends ConsumerWidget {
  const TimeDepositDetailScreen({super.key, required this.depositId});

  final String depositId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(timeDepositDetailProvider(depositId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.valueOrNull == null ? 'Time Deposit' : depositTitle(detail.valueOrNull!.row),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit deposit',
            onPressed: () => context.push('/time-deposits/$depositId/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Time deposit not found.'));
          }
          return _TimeDepositDetailBody(data: data);
        },
      ),
    );
  }
}

class _TimeDepositDetailBody extends ConsumerWidget {
  const _TimeDepositDetailBody({required this.data});

  final TimeDepositDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final row = data.row;
    final deposit = data.deposit;
    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(deposit.startDate);
    final maturity = DateTime.fromMillisecondsSinceEpoch(deposit.maturityDate);
    final days = TimeDepositService.daysBetween(start, maturity);
    final elapsed = TimeDepositService.daysBetween(start, now)
        .clamp(0, days)
        .toDouble();
    final termProgress = days <= 0 ? 0.0 : (elapsed / days).clamp(0.0, 1.0);
    final interest = row.interestCents;
    final daysLeft = row.daysLeft(now);
    final due = row.isDue(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(depositTitle(row), style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  row.account.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  formatMoney(deposit.maturityValueCents, symbol: symbol),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                Text(
                  'Maturity value from ${formatMoney(deposit.principalCents, symbol: symbol)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Term progress',
                        style: theme.textTheme.labelLarge),
                    Text(
                      deposit.isMatured
                          ? 'Matured'
                          : due
                              ? 'Due now'
                              : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: deposit.isMatured
                            ? theme.perakoColors.income
                            : due
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: deposit.isMatured ? 1 : termProgress,
                    minHeight: 8,
                    color: deposit.isMatured
                        ? theme.perakoColors.income
                        : theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                    label: 'Interest method',
                    value: InterestMethod.fromKey(deposit.interestMethod).label),
                _InfoRow(
                  label: 'Annual rate',
                  value: '${(deposit.interestRate * 100).toStringAsFixed(2)}% p.a.',
                ),
                _InfoRow(
                  label: 'Term',
                  value: '$days day${days == 1 ? '' : 's'}',
                ),
                _InfoRow(
                  label: 'Start date',
                  value: _long(
                      DateTime.fromMillisecondsSinceEpoch(deposit.startDate)),
                ),
                _InfoRow(
                  label: 'Maturity date',
                  value: _long(
                      DateTime.fromMillisecondsSinceEpoch(deposit.maturityDate)),
                ),
                _InfoRow(
                  label: 'Interest earned',
                  value: interest <= 0
                      ? '—'
                      : '+${formatMoney(interest, symbol: symbol)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (deposit.isMatured)
          Card(
            color: theme.perakoColors.income.withValues(alpha: 0.1),
            child: ListTile(
              leading: Icon(Icons.check_circle_outline,
                  color: theme.perakoColors.income),
              title: const Text('Interest credited'),
              subtitle: Text(
                deposit.maturedTransactionId == null
                    ? 'This deposit earned no interest.'
                    : 'Income posted to ${row.account.name}.',
              ),
            ),
          )
        else
          FilledButton.icon(
            onPressed: () => _processMaturities(context, ref),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Process maturities now'),
          ),
      ],
    );
  }

  Future<void> _processMaturities(BuildContext context, WidgetRef ref) async {
    final processed = await ref
        .read(timeDepositServiceProvider)
        .processMaturities();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(processed == 0
            ? 'No deposits due yet.'
            : '$processed deposit${processed == 1 ? '' : 's'} matured.'),
      ),
    );
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
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _long(DateTime d) => '${d.month}/${d.day}/${d.year}';
