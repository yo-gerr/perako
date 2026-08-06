import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/bond_service.dart';
import '../providers/bonds_providers.dart';

class BondsListScreen extends ConsumerStatefulWidget {
  const BondsListScreen({super.key});

  @override
  ConsumerState<BondsListScreen> createState() => _BondsListScreenState();
}

class _BondsListScreenState extends ConsumerState<BondsListScreen> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    // Credit due coupons and flag ended terms while the app was closed.
    final service = ref.read(bondServiceProvider);
    service.processCoupons();
    service.processMaturities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bonds')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'fab_bonds',
              onPressed: () => context.push('/bonds/new'),
              tooltip: 'Add bond',
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
          if (!_showArchived) const _MaturityBanner(),
          Expanded(
            child: _showArchived ? _archivedList() : _activeList(),
          ),
        ],
      ),
    );
  }

  Widget _activeList() {
    final rows = ref.watch(bondsProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No bonds yet.\nUse + to create one.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final row in list) _BondCard(row: row),
          ],
        );
      },
    );
  }

  Widget _archivedList() {
    final rows = ref.watch(archivedBondsProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No archived bonds.'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final row in list) _ArchivedBondCard(row: row),
          ],
        );
      },
    );
  }
}

/// Surfaces bonds near the end of their term or already matured.
class _MaturityBanner extends ConsumerWidget {
  const _MaturityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(bondsProvider).valueOrNull;
    if (rows == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final due = rows.where((r) => r.isDue(now)).toList();
    final soon = rows
        .where((r) => !r.isDue(now) && r.daysLeft(now) <= 30)
        .toList();
    if (due.isEmpty && soon.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color =
        due.isEmpty ? theme.colorScheme.tertiary : theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                  due.isEmpty
                      ? Icons.notifications_active_outlined
                      : Icons.timer_off_outlined,
                  size: 18,
                  color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _bannerText(due.length, soon.length),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bannerText(int due, int soon) {
    final parts = <String>[
      if (due > 0)
        '$due bond${due == 1 ? '' : 's'} matured',
      if (soon > 0)
        '$soon term${soon == 1 ? '' : 's'} end${soon == 1 ? 's' : ''} '
        'within 30 days',
    ];
    return parts.join(' · ');
  }
}

class _BondCard extends ConsumerWidget {
  const _BondCard({required this.row});

  final BondRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final bond = row.bond;
    final now = DateTime.now();
    final schedule = CouponSchedule.fromKey(bond.couponSchedule);
    final due = row.isDue(now);
    final color = bond.isMatured
        ? Colors.green
        : due
            ? theme.colorScheme.error
            : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/bonds/${bond.id}'),
        onLongPress: () => _archive(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(
                    bond.isMatured ? Icons.check : Icons.request_quote_outlined,
                    color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bondTitle(row),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.account.name} · '
                      '${(bond.couponRate * 100).toStringAsFixed(2)}% '
                      '${schedule.label.toLowerCase()}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bond.isMatured ? 'Matured' : _countdown(row, now),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BalanceLabel(accountId: bond.accountId, symbol: symbol),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _countdown(BondRow row, DateTime now) {
    final days = row.daysLeft(now);
    if (days <= 0) return 'Term ended';
    return '$days day${days == 1 ? '' : 's'} left in term';
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive bond?'),
        content: Text('"${bondTitle(row)}" will be hidden.'),
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
      await ref.read(bondsDaoProvider).archive(
            row.bond.id,
            nowMillis: DateTime.now().millisecondsSinceEpoch,
          );
    }
  }
}

/// Live ledger balance for an account, refreshed by the engine.
class _BalanceLabel extends ConsumerWidget {
  const _BalanceLabel({required this.accountId, required this.symbol});

  final String accountId;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(accountId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatMoney(balance.valueOrNull ?? 0, symbol: symbol),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          'balance',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ArchivedBondCard extends ConsumerWidget {
  const _ArchivedBondCard({required this.row});

  final BondRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text(bondTitle(row),
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${row.account.name} · '
            '${formatMoney(ref.watch(accountBalanceProvider(row.bond.accountId)).valueOrNull ?? 0, symbol: symbol)}'),
        trailing: TextButton.icon(
          onPressed: () => _reopen(context, ref),
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          label: const Text('Reopen'),
        ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    await ref.read(bondsDaoProvider).reopen(
          row.bond.id,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
        );
  }
}
