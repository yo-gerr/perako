import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../features/categories/presentation/providers/categories_providers.dart';
import '../../domain/report_service.dart';
import '../providers/reports_providers.dart';
import '../widgets/report_screen_scaffold.dart';

/// Spending breakdown by category for the active range.
class SpendingAnalysisScreen extends ConsumerWidget {
  const SpendingAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CategoryAnalysis(
      provider: spendingAnalysisProvider,
      title: 'Spending by Category',
      emptyMessage: 'No spending in this range.',
      symbol: CurrencyScope.of(context),
    );
  }
}

/// Income breakdown by category for the active range.
class IncomeAnalysisScreen extends ConsumerWidget {
  const IncomeAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CategoryAnalysis(
      provider: incomeAnalysisProvider,
      title: 'Income by Category',
      emptyMessage: 'No income in this range.',
      symbol: CurrencyScope.of(context),
    );
  }
}

class _CategoryAnalysis extends ConsumerWidget {
  const _CategoryAnalysis({
    required this.provider,
    required this.title,
    required this.emptyMessage,
    required this.symbol,
  });

  final FutureProvider<List<CategoryAmount>> provider;
  final String title;
  final String emptyMessage;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provider);
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (rows) {
        final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
        final names = {for (final c in categories) c.id: c.name};
        final sorted = [...rows]..sort((a, b) => b.cents.compareTo(a.cents));
        final total = sorted.fold<int>(0, (s, r) => s + r.cents);
        return ReportScreenScaffold(
          title: title,
          csv: ReportService.csvForCategory(
            sorted,
            names,
            column: title.startsWith('Spending') ? 'Spending' : 'Income',
          ),
          child: _body(context, sorted, names, total, symbol, emptyMessage),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<CategoryAmount> rows,
    Map<String, String> names,
    int total,
    String symbol,
    String emptyMessage,
  ) {
    if (rows.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ${formatMoney(total, symbol: symbol)}',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _pie(rows, total),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _LegendRow(
                    index: i,
                    name: rows[i].categoryId == null
                        ? 'Uncategorized'
                        : (names[rows[i].categoryId] ?? 'Unknown'),
                    cents: rows[i].cents,
                    total: total,
                    symbol: symbol,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pie(List<CategoryAmount> rows, int total) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 48,
        sections: [
          for (var i = 0; i < rows.length; i++)
            PieChartSectionData(
              value: rows[i].cents.toDouble(),
              color: _palette[i % _palette.length],
              title: rows[i].cents / total >= 0.05
                  ? '${(rows[i].cents / total * 100).round()}%'
                  : '',
              radius: 64,
              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.index,
    required this.name,
    required this.cents,
    required this.total,
    required this.symbol,
  });

  final int index;
  final String name;
  final int cents;
  final int total;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total <= 0 ? 0.0 : cents / total * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _palette[index % _palette.length],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${pct.toStringAsFixed(0)}%  ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            formatMoney(cents, symbol: symbol),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

const _palette = [
  Color(0xFF00897B),
  Color(0xFF3949AB),
  Color(0xFFF4511E),
  Color(0xFF8E24AA),
  Color(0xFF43A047),
  Color(0xFFFFB300),
  Color(0xFFE53935),
  Color(0xFF00ACC1),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
];
