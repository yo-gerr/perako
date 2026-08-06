import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../features/budgets/presentation/providers/budgets_providers.dart';
import '../widgets/report_screen_scaffold.dart';

/// How each active budget is tracking against its period target.
class BudgetPerformanceScreen extends ConsumerWidget {
  const BudgetPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(budgetsWithProgressProvider);
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (rows) {
        final symbol = CurrencyScope.of(context);
        final csv = _csv(rows);
        return ReportScreenScaffold(
          title: 'Budget Performance',
          showRangeSelector: false,
          csv: csv,
          child: _body(context, rows, symbol),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<BudgetWithProgress> rows,
    String symbol,
  ) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return const Center(child: Text('No active budgets.'));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final row in rows)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.budget.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        row.progress.periodLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatMoney(row.progress.spentCents, symbol: symbol),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: row.progress.isOver
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        ' of ${formatMoney(row.progress.amountCents, symbol: symbol)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(row.progress.ratio * 100).round()}%',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: row.progress.ratio.clamp(0, 1),
                      minHeight: 8,
                      color: row.progress.isOver
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.progress.remainingCents < 0
                        ? 'Over by ${formatMoney(-row.progress.remainingCents, symbol: symbol)}'
                        : '${formatMoney(row.progress.remainingCents, symbol: symbol)} remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: row.progress.remainingCents < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _csv(List<BudgetWithProgress> rows) {
    final lines = [
      'Budget,Period,Spent (cents),Amount (cents),Remaining (cents),Over',
      for (final r in rows)
        [
          r.budget.name,
          r.progress.periodLabel,
          '${r.progress.spentCents}',
          '${r.progress.amountCents}',
          '${r.progress.remainingCents}',
          '${r.progress.isOver}',
        ].join(','),
    ];
    return lines.join('\n');
  }
}
