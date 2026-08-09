import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/perako_colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../account_style.dart';
import '../../domain/account_types.dart';
import '../providers/accounts_providers.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider(accountId));
    final balance = ref.watch(accountBalanceProvider(accountId));
    final entries = ref.watch(accountEntriesProvider(accountId));

    return account.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (acc) {
        if (acc == null) {
          return const Scaffold(body: Center(child: Text('Account not found')));
        }
        final type = AccountType.fromKey(acc.type);
        return Scaffold(
          appBar: AppBar(
            title: Text(acc.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit account',
                onPressed: () =>
                    context.push('/accounts/$accountId/edit'),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'archive') {
                    await ref
                        .read(accountsDaoProvider)
                        .archive(accountId, nowMillis: DateTime.now().millisecondsSinceEpoch);
                    if (context.mounted) context.pop();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                colorFromName(acc.color).withValues(alpha: 0.2),
                            child: FaIcon(iconFromName(acc.icon),
                                color: colorFromName(acc.color)),
                          ),
                          const SizedBox(width: 12),
                          Text(type.label),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Balance',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        balance.when(
                          loading: () => '…',
                          error: (_, _) => '-',
                          data: (cents) =>
                              formatMoney(cents, symbol: CurrencyScope.of(context)),
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (type == AccountType.savings) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: const Text('Savings'),
                    subtitle: const Text('Interest rate and forecast'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/accounts/$accountId/savings'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('History', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              entries.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No activity yet.')),
                      )
                    : Column(
                        children: [
                          for (final e in list)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                e.type == 'debit'
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: e.type == 'debit'
                                    ? Theme.of(context).perakoColors.income
                                    : Theme.of(context).perakoColors.expense,
                              ),
                              title: Text(
                                DateTime.fromMillisecondsSinceEpoch(e.entryDate)
                                    .toString()
                                    .split(' ')[0],
                              ),
                              trailing: Text(
                                '${e.type == 'debit' ? '+' : '-'}${formatMoney(e.amount, symbol: CurrencyScope.of(context))}',
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
