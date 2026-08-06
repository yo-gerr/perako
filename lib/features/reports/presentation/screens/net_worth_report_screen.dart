import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/report_service.dart';
import '../providers/reports_providers.dart';
import '../widgets/report_screen_scaffold.dart';

/// Cumulative balance across all accounts at the end of each bucket.
class NetWorthReportScreen extends ConsumerWidget {
  const NetWorthReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(netWorthReportProvider);
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (points) {
        final symbol = CurrencyScope.of(context);
        return ReportScreenScaffold(
          title: 'Net Worth Report',
          csv: ReportService.csvForNetWorth(points),
          child: _body(context, points, symbol),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<NetWorthPoint> points,
    String symbol,
  ) {
    if (points.isEmpty) {
      return const Center(child: Text('No data in this range.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Summary(
            label: 'Current net worth',
            cents: points.last.cents,
            symbol: symbol,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _chart(context, points, symbol),
          ),
        ],
      ),
    );
  }

  Widget _chart(
    BuildContext context,
    List<NetWorthPoint> points,
    String symbol,
  ) {
    final theme = Theme.of(context);
    final minCents = points.map((p) => p.cents).reduce(math.min);
    final maxCents = points.map((p) => p.cents).reduce(math.max);
    final pad = ((maxCents - minCents) * 0.1).round().clamp(1, 1 << 30);
    final interval = (points.length / 4).ceil().clamp(1, points.length);

    return LineChart(
      LineChartData(
        minY: (minCents - pad).toDouble(),
        maxY: (maxCents + pad).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].cents.toDouble()),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${_tooltipDate(points[spot.x.round()].date)}\n'
                  '${formatMoney(points[spot.x.round()].cents, symbol: symbol)}',
                  TextStyle(color: theme.colorScheme.onInverseSurface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.cents,
    required this.symbol,
  });

  final String label;
  final int cents;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          formatMoney(cents, symbol: symbol),
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
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

Widget _dateTitle(double value, List<NetWorthPoint> points, int interval) {
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
