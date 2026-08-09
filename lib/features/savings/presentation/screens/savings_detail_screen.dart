import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/perako_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/savings_forecast_service.dart';
import '../../domain/savings_interest_service.dart';
import '../providers/savings_providers.dart';

/// Interest rate display, a 12-month balance forecast, and the interest credit
/// history for a savings account.
class SavingsDetailScreen extends ConsumerWidget {
  const SavingsDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(savingsDetailProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.account.name ?? 'Savings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Savings settings',
            onPressed: () =>
                context.push('/accounts/$accountId/savings/settings'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Account not found.'));
          }
          return _SavingsDetailBody(data: data, accountId: accountId);
        },
      ),
    );
  }
}

class _SavingsDetailBody extends ConsumerWidget {
  const _SavingsDetailBody({required this.data, required this.accountId});

  final SavingsDetailData data;
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final savings = data.savings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(data: data, symbol: symbol),
        const SizedBox(height: 12),
        if (savings == null)
          _SetupCard(accountId: accountId)
        else ...[
          _ForecastCard(
            accountId: accountId,
            savings: savings,
            symbol: symbol,
          ),
          const SizedBox(height: 12),
          _NextCreditRow(savings: savings),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _creditInterest(context, ref),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Credit interest now'),
          ),
          const SizedBox(height: 16),
          Text('Interest credits', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (data.schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No interest credits scheduled yet. Save the savings settings '
                'to seed the schedule.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final schedule in data.schedules)
              _ScheduleTile(schedule: schedule, symbol: symbol),
        ],
      ],
    );
  }

  Future<void> _creditInterest(BuildContext context, WidgetRef ref) async {
    final service = ref.read(savingsInterestServiceProvider);
    final credited = await service.accrueDueInterest();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          credited == 0
              ? 'No interest credits due.'
              : '$credited interest credit${credited == 1 ? '' : 's'} posted.',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.symbol});

  final SavingsDetailData data;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savings = data.savings;
    final rate = savings == null ? 0.0 : savings.interestRate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              formatMoney(data.balanceCents, symbol: symbol),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.percent, size: 16),
                const SizedBox(width: 4),
                Text('${(rate * 100).toStringAsFixed(2)}% p.a.'),
                const SizedBox(width: 16),
                const Icon(Icons.repeat, size: 16),
                const SizedBox(width: 4),
                Text(
                  savings == null
                      ? '—'
                      : CompoundingFrequency.fromKey(
                              savings.compoundingFrequency)
                          .label,
                ),
                const Spacer(),
                if (savings?.isPaused ?? false)
                  Chip(
                    label: const Text('Paused'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not configured as a savings account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Set an interest rate and compounding schedule to start earning '
              'interest on this balance.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () =>
                  context.push('/accounts/$accountId/savings/settings'),
              icon: const Icon(Icons.tune),
              label: const Text('Set up savings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends ConsumerWidget {
  const _ForecastCard({
    required this.accountId,
    required this.savings,
    required this.symbol,
  });

  final String accountId;
  final SavingsAccount savings;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(savingsForecastProvider(accountId)).valueOrNull;
    if (forecast == null || forecast.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final finalBalance = forecast.last.balanceCents;
    final interest = finalBalance -
        (ref.watch(savingsDetailProvider(accountId)).valueOrNull
                ?.balanceCents ??
            finalBalance);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('12-month forecast', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Projected balance: ${formatMoney(finalBalance, symbol: symbol)}'
              ' (+${formatMoney(interest, symbol: symbol)})',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: _ForecastChart(points: forecast, symbol: symbol),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.points, required this.symbol});

  final List<ForecastPoint> points;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minCents = points.map((p) => p.balanceCents).reduce(math.min);
    final maxCents = points.map((p) => p.balanceCents).reduce(math.max);
    final pad = ((maxCents - minCents) * 0.1).round().clamp(1, 1 << 30);

    return LineChart(
      LineChartData(
        minY: (minCents - pad).toDouble(),
        maxY: (maxCents + pad).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].balanceCents.toDouble()),
            ],
            isCurved: true,
            color: theme.perakoColors.income,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.perakoColors.income.withValues(alpha: 0.08),
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
              interval: (points.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if ((value - i).abs() > 0.01 ||
                    i < 0 ||
                    i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortDate(points[i].date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
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
                  '${_shortDate(points[spot.x.round()].date)}\n'
                  '${formatMoney(points[spot.x.round()].balanceCents, symbol: symbol)}',
                  TextStyle(color: theme.colorScheme.onInverseSurface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextCreditRow extends ConsumerWidget {
  const _NextCreditRow({required this.savings});

  final SavingsAccount savings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequency = CompoundingFrequency.fromKey(savings.compoundingFrequency);
    final next = SavingsInterestService.nextCreditDate(
      start: DateTime.fromMillisecondsSinceEpoch(savings.startDate),
      frequency: frequency,
      creditDay: savings.interestCreditDay,
      after: DateTime.now(),
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: const Text('Next interest credit'),
        subtitle: Text(_longDate(next)),
        trailing: savings.isPaused
            ? const Chip(label: Text('Paused'))
            : Text('${_daysAway(next)}d away'),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.schedule, required this.symbol});

  final InterestSchedule schedule;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(schedule.dueDate);
    final posted = schedule.transactionId != null;
    final zeroCredit = !posted && schedule.interestCents == 0;
    final icon = posted
        ? Icons.savings_outlined
        : zeroCredit
            ? Icons.remove_circle_outline
            : Icons.event_outlined;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(_longDate(date), style: theme.textTheme.bodyMedium),
        subtitle: Text(posted
            ? 'Interest on ${formatMoney(schedule.principalCents ?? 0, symbol: symbol)}'
            : zeroCredit
                ? 'No interest earned'
                : 'Scheduled'),
        trailing: posted
            ? Text(
                '+${formatMoney(schedule.interestCents ?? 0, symbol: symbol)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.perakoColors.incomeText,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

String _shortDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _longDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

int _daysAway(DateTime d) =>
    DateTime(d.year, d.month, d.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day))
        .inDays;

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
