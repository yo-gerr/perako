import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../core/widgets/custom_dropdown_button2.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/mp2_service.dart';
import '../providers/mp2_accounts_provider.dart';

class Mp2DetailScreen extends ConsumerWidget {
  const Mp2DetailScreen({super.key, required this.mp2Id});

  final String mp2Id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(mp2DetailProvider(mp2Id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.valueOrNull == null ? 'MP2 account' : mp2Title(detail.valueOrNull!.row),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit account',
            onPressed: () => context.push('/mp2/$mp2Id/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('MP2 account not found.'));
          }
          return _Mp2DetailBody(data: data);
        },
      ),
    );
  }
}

class _Mp2DetailBody extends ConsumerWidget {
  const _Mp2DetailBody({required this.data});

  final Mp2DetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final mp2 = data.mp2;
    final row = data.row;
    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(mp2.startDate);
    final maturity = DateTime.fromMillisecondsSinceEpoch(mp2.maturityDate);
    final daysLeft = row.daysLeft(now);
    final due = row.isDue(now);
    final months = Mp2Service.termYears * 12;
    final elapsedMonths = DateTime(now.year, now.month, now.day)
            .difference(DateTime(start.year, start.month, start.day))
            .inDays /
        30.44;
    final termProgress =
        (elapsedMonths / months).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mp2Title(row), style: theme.textTheme.headlineSmall),
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
                      mp2.isMatured
                          ? 'Matured'
                          : due
                              ? 'Term ended'
                              : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: mp2.isMatured
                            ? Colors.green
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
                    value: mp2.isMatured ? 1 : termProgress,
                    minHeight: 8,
                    color: mp2.isMatured
                        ? Colors.green
                        : theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Dividend rate',
                  value: '${(mp2.dividendRate * 100).toStringAsFixed(2)}% p.a.',
                ),
                _InfoRow(
                  label: 'Term',
                  value: '${Mp2Service.termYears} years',
                ),
                _InfoRow(label: 'Start date', value: _long(start)),
                _InfoRow(label: 'Maturity date', value: _long(maturity)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ForecastCard(forecast: data.forecast, symbol: symbol),
        const SizedBox(height: 12),
        _DividendHistory(mp2Id: mp2.id, symbol: symbol),
        const SizedBox(height: 12),
        if (!mp2.isMatured) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openMoveSheet(context, ref, isContribute: true),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Contribute'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openMoveSheet(context, ref, isContribute: false),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Withdraw'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _processDividends(context, ref),
            icon: const Icon(Icons.percent_outlined),
            label: const Text('Realize dividends now'),
          ),
        ],
      ],
    );
  }

  void _openMoveSheet(BuildContext context, WidgetRef ref,
      {required bool isContribute}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoveSheet(
        data: data,
        isContribute: isContribute,
      ),
    );
  }

  Future<void> _processDividends(BuildContext context, WidgetRef ref) async {
    final processed =
        await ref.read(mp2ServiceProvider).processDividends();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(processed == 0
            ? 'No dividends due yet.'
            : '$processed dividend${processed == 1 ? '' : 's'} realized.'),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.symbol});

  final List<Mp2DividendForecast> forecast;
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
            Text('Upcoming dividends', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            if (forecast.isEmpty)
              Text(
                'No more dividends to credit.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final f in forecast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Year ${f.yearNumber} · ${_short(f.anniversary)}',
                          style: theme.textTheme.bodyMedium),
                      Text('+${formatMoney(f.dividendCents, symbol: symbol)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.green)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DividendHistory extends ConsumerWidget {
  const _DividendHistory({required this.mp2Id, required this.symbol});

  final String mp2Id;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dividends =
        ref.watch(mp2DividendsProvider(mp2Id)).valueOrNull ?? [];
    final total = dividends.fold<int>(0, (sum, d) => sum + d.amountCents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dividends realized', style: theme.textTheme.labelLarge),
                Text(
                  '+${formatMoney(total, symbol: symbol)}',
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dividends.isEmpty)
              Text(
                'None credited yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final d in dividends.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Year ${d.year + 1} · '
                        '${_long(DateTime.fromMillisecondsSinceEpoch(d.paidOn))}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        d.amountCents == 0 ? '—' : '+${formatMoney(d.amountCents, symbol: symbol)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: d.amountCents == 0
                                ? theme.colorScheme.onSurfaceVariant
                                : Colors.green),
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

/// Bottom sheet for contributing to or withdrawing from an MP2 account.
class _MoveSheet extends ConsumerStatefulWidget {
  const _MoveSheet({required this.data, required this.isContribute});

  final Mp2DetailData data;
  final bool isContribute;

  @override
  ConsumerState<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<_MoveSheet> {
  final _amount = TextEditingController();
  String? _otherAccountId;
  DateTime? _date;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mp2 = widget.data.mp2;
    final otherAccounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
            .where((a) => !a.isArchived && a.id != mp2.accountId)
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isContribute
                ? 'Contribute to ${mp2Title(widget.data.row)}'
                : 'Withdraw from ${mp2Title(widget.data.row)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CustomDropdownButton2<String?>(
            hint: widget.isContribute ? 'From account' : 'To account',
            dropdownItems: [
              for (final a in otherAccounts) a.id,
            ],
            itemLabel: (id) =>
                otherAccounts.firstWhere((a) => a.id == id).name,
            initialValue: _otherAccountId,
            onChanged: (v) => setState(() => _otherAccountId = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined, size: 20),
            label: Text(_date == null ? 'Date (today)' : _short(_date!)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.isContribute ? 'Contribute' : 'Withdraw'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    final amountCents = parseMoneyCents(_amount.text);
    if (amountCents == null || amountCents <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_otherAccountId == null) {
      setState(() {
        _error =
            widget.isContribute ? 'Pick the source account.' : 'Pick the destination account.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final service = ref.read(mp2ServiceProvider);
    try {
      if (widget.isContribute) {
        await service.contribute(
          widget.data.mp2,
          sourceAccountId: _otherAccountId!,
          amountCents: amountCents,
          on: _date,
        );
      } else {
        await service.withdraw(
          widget.data.mp2,
          toAccountId: _otherAccountId!,
          amountCents: amountCents,
          on: _date,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _short(DateTime d) => '${d.month}/${d.day}/${d.year}';
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
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _long(DateTime d) => '${d.month}/${d.day}/${d.year}';
String _short(DateTime d) => '${d.month}/${d.day}/${d.year}';
