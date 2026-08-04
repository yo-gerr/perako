import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/home_shell.dart';
import '../../../../core/utils/formatters.dart';
import '../account_style.dart';
import '../../domain/account_types.dart';
import '../providers/accounts_providers.dart';

class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => HomeShell.of(context).openDrawer(),
        ),
        title: const Text('Accounts'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_accounts',
        onPressed: () => context.push('/accounts/new'),
        tooltip: 'Add account',
        child: const Icon(Icons.add),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No accounts yet.\nUse + to create one.',
                  textAlign: TextAlign.center),
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
    );
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
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(account.id));
    final type = AccountType.fromKey(account.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorFromName(account.color).withValues(alpha: 0.2),
          child: Icon(iconFromName(account.icon),
              color: colorFromName(account.color)),
        ),
        title: Text(account.name),
        subtitle: Text(type.label),
        trailing: balance.when(
          loading: () => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => const Text('-'),
          data: (cents) => Text(
            formatMoney(cents),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cents < 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
          ),
        ),
        onTap: () => context.push('/accounts/${account.id}'),
      ),
    );
  }
}
