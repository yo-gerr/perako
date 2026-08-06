import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/report_service.dart';
import '../providers/reports_providers.dart';
import '../widgets/report_screen_scaffold.dart';

/// Income vs expense per bucket, shown as grouped bars.
class CashFlowReportScreen extends ConsumerWidget {
  const CashFlowReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(cashFlowReportProvider);
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (points) {
        final symbol = CurrencyScope.of(context);
        final income = points.fold<int>(0, (s, p) => s + p.incomeCents);
        final expense = points.fold<int>(0, (s, p) => s + p.expenseCents);
        return ReportScreenScaffold(
          title: 'Cash Flow Report',
          csv: ReportService.csvForCashFlow(points),
          child: _body(context, points, income, expense, symbol),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<CashFlowPoint> points,
    int totalIncome,
    int totalExpense,
    String symbol,
  ) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return const Center(child: Text('No data in this range.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendPill(
                color: Colors.green,
                label: 'Income ${formatMoney(totalIncome, symbol: symbol)}',
              ),
              const SizedBox(width: 12),
              _LegendPill(
                color: theme.colorScheme.error,
                label:
                    'Expense ${formatMoney(totalExpense, symbol: symbol)}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _chart(context, points, symbol)),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, List<CashFlowPoint> points, String symbol) {
    final theme = Theme.of(context);
    final maxCents = [
      ...points.map((p) => p.incomeCents),
      ...points.map((p) => p.expenseCents),
    ].reduce(math.max);
    final interval = (points.length / 4).ceil().clamp(1, points.length);

    return BarChart(
      BarChartData(
        maxY: (maxCents * 1.15).clamp(1, 1 << 62).toDouble(),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: points[i].incomeCents.toDouble(),
                  color: Colors.green,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: points[i].expenseCents.toDouble(),
                  color: theme.colorScheme.error,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 72,
              getTitlesWidget: (value, meta) => Text(
                _axisMoney(value.round(), symbol),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval.toDouble(),
              getTitlesWidget: (value, meta) =>
                  _dateTitle(value, points, interval),
            ),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[groupIndex];
              final value =
                  rodIndex == 0 ? p.incomeCents : p.expenseCents;
              return BarTooltipItem(
                '${rodIndex == 0 ? 'Income' : 'Expense'}: '
                '${formatMoney(value, symbol: symbol)}\n'
                '${_tooltipDate(p.date)}',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _axisMoney(int cents, String symbol) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  String body;
  if (abs >= 100000000) {
    body = '$symbol${(abs / 100000000).toStringAsFixed(1)}M';
  } else if (abs >= 100000) {
    body = '$symbol${(abs / 100000).toStringAsFixed(1)}K';
  } else {
    body = formatMoney(cents, symbol: symbol);
  }
  return sign + body;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _tooltipDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

Widget _dateTitle(double value, List<CashFlowPoint> points, int interval) {
  final i = value.round();
  if ((value - i).abs() > 0.01) return const SizedBox.shrink();
  if (i % interval != 0) return const SizedBox.shrink();
  if (i < 0 || i >= points.length) return const SizedBox.shrink();
  final d = points[i].date;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      '${_months[d.month - 1]} ${d.day}',
      style: const TextStyle(fontSize: 10),
    ),
  );
}
