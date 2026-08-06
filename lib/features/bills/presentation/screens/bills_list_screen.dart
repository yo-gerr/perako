import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/bill_service.dart';
import '../providers/bills_providers.dart';

class BillsListScreen extends ConsumerStatefulWidget {
  const BillsListScreen({super.key});

  @override
  ConsumerState<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends ConsumerState<BillsListScreen> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    // Materialize any bills that came due while the app was closed (or that
    // were just created with a past due date). Idempotent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billServiceProvider).catchUpDueBills();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'fab_bills',
              onPressed: () => context.push('/bills/new'),
              tooltip: 'Add bill',
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Active'),
                    icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(
                    value: true,
                    label: Text('Archived'),
                    icon: Icon(Icons.archive_outlined)),
              ],
              selected: {_showArchived},
              onSelectionChanged: (s) => setState(() => _showArchived = s.first),
            ),
          ),
          Expanded(
            child: _showArchived ? _archivedList() : _activeList(),
          ),
        ],
      ),
    );
  }

  Widget _activeList() {
    final bills = ref.watch(billsProvider);
    return bills.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No bills yet.\nUse + to add one.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final symbol = CurrencyScope.of(context);
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final bill in list)
              _BillCard(bill: bill, symbol: symbol),
          ],
        );
      },
    );
  }

  Widget _archivedList() {
    final bills = ref.watch(archivedBillsProvider);
    return bills.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No archived bills.'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final bill in list) _ArchivedBillCard(bill: bill),
          ],
        );
      },
    );
  }
}

/// Relative due status for a bill, e.g. "Due in 3 days", "Overdue", "Due today".
({String text, bool overdue, bool dueSoon}) _dueStatus(
  Bill bill,
  DateTime now,
) {
  final due = DateTime.fromMillisecondsSinceEpoch(bill.nextDueDate);
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final days = dueDay.difference(today).inDays;

  if (days < 0) return (text: 'Overdue', overdue: true, dueSoon: false);
  if (days == 0) return (text: 'Due today', overdue: false, dueSoon: true);
  if (days == 1) return (text: 'Due tomorrow', overdue: false, dueSoon: true);
  if (days <= 7) return (text: 'Due in $days days', overdue: false, dueSoon: true);
  return (text: 'Due ${dueDay.month}/${dueDay.day}', overdue: false, dueSoon: false);
}

class _BillCard extends ConsumerWidget {
  const _BillCard({required this.bill, required this.symbol});

  final Bill bill;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = _dueStatus(bill, DateTime.now());
    final color = status.overdue
        ? theme.colorScheme.error
        : status.dueSoon
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/bills/${bill.id}'),
        onLongPress: () => _archive(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.receipt_long_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${BillFrequency.fromKey(bill.frequency).label} · '
                      '${formatMoney(bill.amountCents, symbol: symbol)}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.text,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(bill.amountCents, symbol: symbol),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive bill?'),
        content: Text('"${bill.name}" will be hidden.'),
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
      await ref.read(billsDaoProvider).archive(
            bill.id,
            nowMillis: DateTime.now().millisecondsSinceEpoch,
          );
    }
  }
}

class _ArchivedBillCard extends ConsumerWidget {
  const _ArchivedBillCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text(bill.name,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${BillFrequency.fromKey(bill.frequency).label} · '
            '${formatMoney(bill.amountCents)}'),
        trailing: TextButton.icon(
          onPressed: () => _reopen(context, ref),
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          label: const Text('Reopen'),
        ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    await ref.read(billsDaoProvider).reopen(
          bill.id,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
        );
  }
}
