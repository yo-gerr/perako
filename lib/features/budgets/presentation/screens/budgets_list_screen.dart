import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/budget_service.dart';
import '../providers/budgets_providers.dart';

class BudgetsListScreen extends ConsumerStatefulWidget {
  const BudgetsListScreen({super.key});

  @override
  ConsumerState<BudgetsListScreen> createState() => _BudgetsListScreenState();
}

class _BudgetsListScreenState extends ConsumerState<BudgetsListScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'fab_budgets',
              onPressed: () => context.push('/budgets/new'),
              tooltip: 'Add budget',
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
    final budgets = ref.watch(budgetsWithProgressProvider);
    return budgets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No budgets yet.\nUse + to create one.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final symbol = CurrencyScope.of(context);
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final row in list)
              _BudgetCard(
                budget: row.budget,
                progress: row.progress,
                symbol: symbol,
              ),
          ],
        );
      },
    );
  }

  Widget _archivedList() {
    final budgets = ref.watch(archivedBudgetsProvider);
    return budgets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('No archived budgets.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final budget in list)
              _ArchivedCard(budget: budget),
          ],
        );
      },
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({
    required this.budget,
    required this.progress,
    required this.symbol,
  });

  final Budget budget;
  final BudgetProgress progress;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = progress.isOver
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final pct = (progress.ratio * 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/budgets/${budget.id}'),
        onLongPress: () => _archive(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ProgressRing(
                ratio: progress.ratio,
                color: color,
                label: '$pct%',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(budget.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${progress.periodLabel} · '
                      '${formatMoney(progress.spentCents, symbol: symbol)} / '
                      '${formatMoney(progress.amountCents, symbol: symbol)}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.ratio.clamp(0, 1),
                        minHeight: 6,
                        color: color,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.remainingCents < 0
                          ? 'Over by ${formatMoney(-progress.remainingCents, symbol: symbol)}'
                          : '${formatMoney(progress.amountPerDayCents, symbol: symbol)}/day left',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: progress.remainingCents < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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
        title: const Text('Archive budget?'),
        content: Text('"${budget.name}" will be hidden.'),
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
      await ref.read(budgetsDaoProvider).archive(
            budget.id,
            nowMillis: DateTime.now().millisecondsSinceEpoch,
          );
    }
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.ratio,
    required this.color,
    required this.label,
  });
  final double ratio;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = ratio.clamp(0.0, 1.0);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            color: color,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ArchivedCard extends ConsumerWidget {
  const _ArchivedCard({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text(budget.name,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${BudgetPeriod.fromKey(budget.period).label} · '
            '${formatMoney(budget.amountCents)}'),
        trailing: TextButton.icon(
          onPressed: () => _reopen(context, ref),
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          label: const Text('Reopen'),
        ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    await ref.read(budgetsDaoProvider).reopen(
          budget.id,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
        );
  }
}
