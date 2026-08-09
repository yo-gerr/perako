import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/perako_colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../providers/mp2_accounts_provider.dart';

class Mp2ListScreen extends ConsumerStatefulWidget {
  const Mp2ListScreen({super.key});

  @override
  ConsumerState<Mp2ListScreen> createState() => _Mp2ListScreenState();
}

class _Mp2ListScreenState extends ConsumerState<Mp2ListScreen> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    // Realize dividends and flag ended terms while the app was closed.
    final service = ref.read(mp2ServiceProvider);
    service.processDividends();
    service.processMaturities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MP2')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'fab_mp2',
              onPressed: () => context.push('/mp2/new'),
              tooltip: 'Add MP2 account',
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
    final rows = ref.watch(mp2AccountsProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No MP2 accounts yet.\nUse + to create one.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final row in list) _Mp2Card(row: row),
          ],
        );
      },
    );
  }

  Widget _archivedList() {
    final rows = ref.watch(archivedMp2AccountsProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No archived MP2 accounts.'));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final row in list) _ArchivedMp2Card(row: row),
          ],
        );
      },
    );
  }
}

/// Surfaces accounts close to the end of their 5-year term.
class _MaturityBanner extends ConsumerWidget {
  const _MaturityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(mp2AccountsProvider).valueOrNull;
    if (rows == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final due = rows.where((r) => r.isDue(now)).toList();
    final soon = rows
        .where((r) => !r.isDue(now) && r.daysLeft(now) <= 30)
        .toList();
    if (due.isEmpty && soon.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color =
        due.isEmpty ? theme.colorScheme.secondary : theme.colorScheme.error;

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
        '$due MP2 account${due == 1 ? '' : 's'} matured',
      if (soon > 0)
        '$soon term${soon == 1 ? '' : 's'} end${soon == 1 ? 's' : ''} '
        'within 30 days',
    ];
    return parts.join(' · ');
  }
}

class _Mp2Card extends ConsumerWidget {
  const _Mp2Card({required this.row});

  final Mp2Row row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final mp2 = row.mp2;
    final now = DateTime.now();
    final due = row.isDue(now);
    final color = mp2.isMatured
        ? theme.perakoColors.income
        : due
            ? theme.colorScheme.error
            : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/mp2/${mp2.id}'),
        onLongPress: () => _archive(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(
                    mp2.isMatured ? Icons.check : Icons.account_balance_outlined,
                    color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mp2Title(row),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.account.name} · '
                      '${(mp2.dividendRate * 100).toStringAsFixed(2)}% p.a.',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mp2.isMatured
                          ? 'Matured'
                          : _countdown(row, now),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BalanceLabel(accountId: mp2.accountId, symbol: symbol),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _countdown(Mp2Row row, DateTime now) {
    final days = row.daysLeft(now);
    if (days <= 0) return 'Term ended';
    return '$days day${days == 1 ? '' : 's'} left in term';
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive MP2 account?'),
        content: Text('"${mp2Title(row)}" will be hidden.'),
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
      await ref.read(mp2DaoProvider).archive(
            row.mp2.id,
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

class _ArchivedMp2Card extends ConsumerWidget {
  const _ArchivedMp2Card({required this.row});

  final Mp2Row row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.archive_outlined),
        title: Text(mp2Title(row),
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${row.account.name} · '
            '${formatMoney(ref.watch(accountBalanceProvider(row.mp2.accountId)).valueOrNull ?? 0, symbol: symbol)}'),
        trailing: TextButton.icon(
          onPressed: () => _reopen(context, ref),
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          label: const Text('Reopen'),
        ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    await ref.read(mp2DaoProvider).reopen(
          row.mp2.id,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
        );
  }
}
