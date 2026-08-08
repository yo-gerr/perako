import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../core/widgets/custom_dropdown_button2.dart';
import '../../../categories/domain/category_types.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../providers/budgets_providers.dart';

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(budgetDetailProvider(budgetId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.budget.name ?? 'Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit budget',
            onPressed: () => context.push('/budgets/$budgetId/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Budget not found.'));
          }
          return _BudgetDetailBody(data: data, budgetId: budgetId);
        },
      ),
    );
  }
}

class _BudgetDetailBody extends ConsumerWidget {
  const _BudgetDetailBody({required this.data, required this.budgetId});

  final BudgetDetailData data;
  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final progress = data.progress;
    final color = progress.isOver
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final pct = (progress.ratio * 100).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.ratio.clamp(0, 1),
                        strokeWidth: 8,
                        color: color,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      Text('$pct%', style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(progress.periodLabel,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Spent ${formatMoney(progress.spentCents, symbol: symbol)} '
                        'of ${formatMoney(progress.amountCents, symbol: symbol)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress.remainingCents < 0
                            ? 'Over by ${formatMoney(-progress.remainingCents, symbol: symbol)}'
                            : '${formatMoney(progress.remainingCents, symbol: symbol)} left',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: progress.remainingCents < 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _StatRow(
                  label: 'Daily allowance left',
                  value:
                      '${formatMoney(progress.amountPerDayCents, symbol: symbol)}/day'),
              const Divider(height: 1),
              _StatRow(
                label: 'Forecast at period end',
                value: formatMoney(progress.forecastCents, symbol: symbol),
                over: progress.forecastCents > progress.amountCents,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Category limits', style: theme.textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => _addLimit(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (data.limits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No per-category limits. Add limits to keep specific categories in check.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final row in data.limits) _LimitTile(row: row, symbol: symbol),
      ],
    );
  }

  Future<void> _addLimit(BuildContext context, WidgetRef ref) async {
    final expenseCategories =
        (ref.read(categoriesProvider).valueOrNull ?? const [])
            .where((c) => CategoryType.fromKey(c.type) == CategoryType.expense)
            .where((c) => !data.limits.any((l) => l.limit.categoryId == c.id))
            .toList();
    if (expenseCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Every expense category already has a limit.')));
      return;
    }
    if (!context.mounted) return;

    final result = await showDialog<({String categoryId, int amountCents})>(
      context: context,
      builder: (_) => _LimitDialog(categories: expenseCategories),
    );
    if (result == null) return;

    final dao = ref.read(budgetsDaoProvider);
    final existing = await dao.limitsFor(budgetId);
    await dao.replaceLimits(budgetId, [
      for (final l in existing)
        CategoryBudgetLimitsCompanion(
          id: Value(l.id),
          budgetId: Value(l.budgetId),
          categoryId: Value(l.categoryId),
          amountCents: Value(l.amountCents),
          updatedAt: Value(l.updatedAt),
        ),
      CategoryBudgetLimitsCompanion(
        id: Value('lim_${DateTime.now().microsecondsSinceEpoch}'),
        budgetId: Value(budgetId),
        categoryId: Value(result.categoryId),
        amountCents: Value(result.amountCents),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    ]);
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.over = false});

  final String label;
  final String value;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: over ? theme.colorScheme.error : null,
          fontWeight: over ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({required this.row, required this.symbol});

  final CategoryLimitProgress row;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = row.limit;
    final spent = row.spentCents;
    final over = spent > limit.amountCents;
    final color =
        over ? theme.colorScheme.error : theme.colorScheme.primary;
    final ratio = limit.amountCents <= 0 ? 0.0 : spent / limit.amountCents;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(row.category?.name ?? 'Unknown category',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${formatMoney(spent, symbol: symbol)} / '
                  '${formatMoney(limit.amountCents, symbol: symbol)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 5,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.categories});

  final List<dynamic> categories;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  final _amount = TextEditingController();
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isNotEmpty
        ? widget.categories.first.id
        : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add category limit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomDropdownButton2<String>(
            hint: 'Category',
            dropdownItems: [
              for (final c in widget.categories) c.id,
            ],
            itemLabel: (id) =>
                widget.categories.firstWhere((c) => c.id == id).name,
            initialValue: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Limit amount',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final amount = parseMoneyCents(_amount.text);
            final categoryId = _categoryId;
            if (amount == null || categoryId == null) return;
            Navigator.of(context).pop(
              (categoryId: categoryId, amountCents: amount),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
