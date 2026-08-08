import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../account_style.dart';
import '../../domain/account_types.dart';
import '../providers/accounts_providers.dart';

class AccountsListScreen extends ConsumerStatefulWidget {
  const AccountsListScreen({super.key});

  @override
  ConsumerState<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends ConsumerState<AccountsListScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(_showArchived
        ? archivedAccountsProvider
        : accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'fab_accounts',
              onPressed: () => context.push('/accounts/new'),
              tooltip: 'Add account',
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
            child: accounts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _showArchived
                          ? 'No archived accounts.'
                          : 'No accounts yet.\nUse + to create one.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (_showArchived) {
                  return ListView(
                    children: [
                      for (final a in list)
                        _AccountTile(account: a, onReopen: () => _reopen(a)),
                    ],
                  );
                }
                final assets = list
                    .where((a) => !AccountType.fromKey(a.type).isLiability)
                    .toList();
                final liabilities = list
                    .where((a) => AccountType.fromKey(a.type).isLiability)
                    .toList();

                return ListView(
                  children: [
                    if (assets.isNotEmpty) ...[
                      _SectionHeader('Assets'),
                      ...assets.map((a) => _AccountTile(account: a)),
                    ],
                    if (liabilities.isNotEmpty) ...[
                      _SectionHeader('Liabilities'),
                      ...liabilities.map((a) => _AccountTile(account: a)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reopen(Account account) async {
    await ref
        .read(accountsDaoProvider)
        .reopen(account.id, nowMillis: DateTime.now().millisecondsSinceEpoch);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, this.onReopen});

  final Account account;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(account.id));
    final type = AccountType.fromKey(account.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorFromName(account.color).withValues(alpha: 0.2),
          child: FaIcon(iconFromName(account.icon),
              color: colorFromName(account.color)),
        ),
        title: Text(account.name),
        subtitle: Text(type.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            balance.when(
              loading: () => const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => const Text('-'),
              data: (cents) => Text(
                formatMoney(cents, symbol: CurrencyScope.of(context)),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cents < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
              ),
            ),
            if (onReopen != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Reopen',
                onPressed: onReopen,
              ),
            ],
          ],
        ),
        onTap: () => context.push('/accounts/${account.id}'),
      ),
    );
  }
}
