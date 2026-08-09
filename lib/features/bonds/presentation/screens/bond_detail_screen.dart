import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/perako_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../domain/bond_service.dart';
import '../providers/bonds_providers.dart';

class BondDetailScreen extends ConsumerWidget {
  const BondDetailScreen({super.key, required this.bondId});

  final String bondId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(bondDetailProvider(bondId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.valueOrNull == null ? 'Bond' : bondTitle(detail.valueOrNull!.row),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit bond',
            onPressed: () => context.push('/bonds/$bondId/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Bond not found.'));
          }
          return _BondDetailBody(data: data);
        },
      ),
    );
  }
}

class _BondDetailBody extends ConsumerWidget {
  const _BondDetailBody({required this.data});

  final BondDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final bond = data.bond;
    final row = data.row;
    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(bond.startDate);
    final maturity = DateTime.fromMillisecondsSinceEpoch(bond.maturityDate);
    final schedule = CouponSchedule.fromKey(bond.couponSchedule);
    final perCoupon = BondService.couponAmount(
      faceValueCents: bond.faceValueCents,
      couponRate: bond.couponRate,
      schedule: schedule,
    );
    final daysLeft = row.daysLeft(now);
    final due = row.isDue(now);
    final totalDays = maturity.difference(start).inDays;
    final elapsed =
        now.difference(start).inDays.clamp(0, totalDays).toDouble();
    final termProgress =
        totalDays <= 0 ? 0.0 : (elapsed / totalDays).clamp(0.0, 1.0);
    final next = data.nextCouponDate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bondTitle(row), style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  row.account.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  formatMoney(data.balanceCents, symbol: symbol),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                Text(
                  'balance · projected '
                  '${formatMoney(data.maturityValueCents, symbol: symbol)} '
                  'at maturity',
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
                    Text('Term progress', style: theme.textTheme.labelLarge),
                    Text(
                      bond.isMatured
                          ? 'Matured'
                          : due
                              ? 'Term ended'
                              : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: bond.isMatured
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
                    value: bond.isMatured ? 1 : termProgress,
                    minHeight: 8,
                    color: bond.isMatured
                        ? theme.perakoColors.income
                        : theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Coupon',
                  value: '${(bond.couponRate * 100).toStringAsFixed(2)}% p.a. '
                      '${schedule.label.toLowerCase()}',
                ),
                _InfoRow(
                  label: 'Face value',
                  value: formatMoney(bond.faceValueCents, symbol: symbol),
                ),
                _InfoRow(
                  label: 'Coupon per period',
                  value: formatMoney(perCoupon, symbol: symbol),
                ),
                _InfoRow(label: 'Start date', value: _long(start)),
                _InfoRow(label: 'Maturity date', value: _long(maturity)),
                _InfoRow(
                  label: 'Next payment',
                  value: next == null
                      ? '—'
                      : next.isAfter(now)
                          ? '${_long(next)} · '
                              '+${formatMoney(perCoupon, symbol: symbol)}'
                          : 'Due now',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ForecastCard(
          dates: data.remainingCouponDates,
          perCouponCents: perCoupon,
          totalCents: data.forecastCouponCents,
          symbol: symbol,
        ),
        const SizedBox(height: 12),
        _CouponHistory(bondId: bond.id, symbol: symbol),
        const SizedBox(height: 12),
        if (!bond.isMatured)
          OutlinedButton.icon(
            onPressed: () => _processCoupons(context, ref),
            icon: const Icon(Icons.percent_outlined),
            label: const Text('Realize coupons now'),
          ),
      ],
    );
  }

  Future<void> _processCoupons(BuildContext context, WidgetRef ref) async {
    final processed = await ref.read(bondServiceProvider).processCoupons();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(processed == 0
            ? 'No coupons due yet.'
            : '$processed coupon${processed == 1 ? '' : 's'} realized.'),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.dates,
    required this.perCouponCents,
    required this.totalCents,
    required this.symbol,
  });

  final List<DateTime> dates;
  final int perCouponCents;
  final int totalCents;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming coupons', style: theme.textTheme.labelLarge),
                Text(
                  '+${formatMoney(totalCents, symbol: symbol)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.perakoColors.incomeText,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dates.isEmpty)
              Text(
                'No more coupons to pay.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final d in dates)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_long(d), style: theme.textTheme.bodyMedium),
                      Text('+${formatMoney(perCouponCents, symbol: symbol)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.perakoColors.incomeText)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CouponHistory extends ConsumerWidget {
  const _CouponHistory({required this.bondId, required this.symbol});

  final String bondId;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coupons =
        ref.watch(bondCouponsProvider(bondId)).valueOrNull ?? [];
    final total = coupons.fold<int>(0, (sum, c) => sum + c.couponCents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Coupons received', style: theme.textTheme.labelLarge),
                Text(
                  '+${formatMoney(total, symbol: symbol)}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.perakoColors.incomeText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (coupons.isEmpty)
              Text(
                'None credited yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final c in coupons.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Coupon ${c.period + 1} · '
                        '${_long(DateTime.fromMillisecondsSinceEpoch(c.paidOn))}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        c.couponCents == 0
                            ? '—'
                            : '+${formatMoney(c.couponCents, symbol: symbol)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.couponCents == 0
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.perakoColors.incomeText),
                      ),
                    ],
                  ),
                ),
          ],
        ),
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
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

String _long(DateTime d) => '${d.month}/${d.day}/${d.year}';
