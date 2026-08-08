import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../core/widgets/custom_dropdown_button2.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/goal_service.dart';
import '../providers/goals_providers.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(goalDetailProvider(goalId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.goal.name ?? 'Goal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit goal',
            onPressed: () => context.push('/goals/$goalId/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Goal not found.'));
          }
          return _GoalDetailBody(data: data, goalId: goalId);
        },
      ),
    );
  }
}

class _GoalDetailBody extends ConsumerWidget {
  const _GoalDetailBody({required this.data, required this.goalId});

  final GoalDetailData data;
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final goal = data.goal;
    final progress = data.progress;
    final accounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[]);
    final funding =
        accounts.where((a) => a.id == goal.fundingAccountId).toList();
    final fundingName = funding.isEmpty ? null : funding.first.name;
    final forecast = data.progress.isComplete
        ? null
        : ref.read(goalServiceProvider).forecastCompletion(goal);
    final suggested =
        ref.read(goalServiceProvider).suggestedMonthlyContribution(goal);

    return ListView(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal.name, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            GoalType.fromKey(goal.type).label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _ProgressRing(
                      ratio: progress.ratio,
                      color: progress.isComplete
                          ? Colors.green
                          : theme.colorScheme.primary,
                      label: '${(progress.ratio * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  formatMoney(progress.currentCents, symbol: symbol),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                Text(
                  'of ${formatMoney(progress.targetCents, symbol: symbol)}',
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
              children: [
                if (fundingName != null)
                  _InfoRow(label: 'Funded from', value: fundingName),
                if (goal.targetDate != null)
                  _InfoRow(
                    label: 'Target date',
                    value: _dateLabel(
                        DateTime.fromMillisecondsSinceEpoch(goal.targetDate!)),
                  ),
                _InfoRow(
                  label: 'Remaining',
                  value: progress.isComplete
                      ? 'Done'
                      : formatMoney(progress.remainingCents, symbol: symbol),
                ),
                _InfoRow(
                  label: 'Time left',
                  value: progress.daysLeft <= 0
                      ? 'Past due'
                      : '${progress.daysLeft} day${progress.daysLeft == 1 ? '' : 's'}',
                ),
                _InfoRow(
                  label: 'Forecast',
                  value: progress.isComplete
                      ? 'Completed'
                      : forecast == null
                          ? 'Not enough data'
                          : '${forecast.month}/${forecast.day}/${forecast.year}',
                ),
                _InfoRow(
                  label: 'Suggested / month',
                  value: suggested <= 0
                      ? '—'
                      : formatMoney(suggested, symbol: symbol),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: progress.isComplete
              ? null
              : () => _contribute(context, ref),
          icon: const Icon(Icons.add_card_outlined),
          label: const Text('Contribute'),
        ),
        const SizedBox(height: 16),
        Text('Contributions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (data.contributions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No contributions yet. Contributions move money from an '
              'account into this goal.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final c in data.contributions)
            _ContributionTile(contribution: c, symbol: symbol),
      ],
    );
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref) async {
    final goal = data.goal;
    final accounts =
        (ref.read(accountsProvider).valueOrNull ?? const <Account>[])
            .where((a) => !a.isArchived)
            .where((a) => a.id != goal.fundingAccountId)
            .toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add another account to contribute from.')),
      );
      return;
    }

    final result = await showDialog<({String sourceAccountId, int amountCents,
        String? note})>(
      context: context,
      builder: (_) => _ContributeDialog(accounts: accounts),
    );
    if (result == null || !context.mounted) return;

    await ref.read(goalServiceProvider).contribute(
          goal,
          sourceAccountId: result.sourceAccountId,
          amountCents: result.amountCents,
          note: result.note,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${formatMoney(result.amountCents)} added to "${goal.name}".'),
        ),
      );
    }
  }
}

String _dateLabel(DateTime d) => '${d.month}/${d.day}/${d.year}';

class _ContributeDialog extends StatefulWidget {
  const _ContributeDialog({required this.accounts});

  final List<Account> accounts;

  @override
  State<_ContributeDialog> createState() => _ContributeDialogState();
}

class _ContributeDialogState extends State<_ContributeDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _accountId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amountCents = parseMoneyCents(_amount.text);
    if (amountCents == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick the account to contribute from.');
      return;
    }
    final note = _note.text.trim();
    Navigator.of(context).pop((
      sourceAccountId: _accountId!,
      amountCents: amountCents,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Contribute'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomDropdownButton2<String?>(
            hint: 'From account',
            dropdownItems: [
              for (final a in widget.accounts) a.id,
            ],
            itemLabel: (id) =>
                widget.accounts.firstWhere((a) => a.id == id).name,
            initialValue: _accountId,
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
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
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.ratio, required this.color, required this.label});
  final double ratio;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = ratio.clamp(0.0, 1.0);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({required this.contribution, required this.symbol});

  final GoalContribution contribution;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = DateTime.fromMillisecondsSinceEpoch(contribution.contributedOn);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.add_card_outlined),
        title: Text(
          '${on.month}/${on.day}/${on.year}',
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: contribution.note == null || contribution.note!.isEmpty
            ? null
            : Text(contribution.note!),
        trailing: Text(
          formatMoney(contribution.amountCents, symbol: symbol),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
