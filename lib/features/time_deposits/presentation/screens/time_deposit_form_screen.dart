import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../../core/widgets/custom_dropdown_button2.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/time_deposit_service.dart';
import '../providers/time_deposits_providers.dart';

class TimeDepositFormScreen extends ConsumerStatefulWidget {
  const TimeDepositFormScreen({super.key, this.depositId});

  final String? depositId;

  @override
  ConsumerState<TimeDepositFormScreen> createState() =>
      _TimeDepositFormScreenState();
}

class _TimeDepositFormScreenState extends ConsumerState<TimeDepositFormScreen> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  InterestMethod _method = InterestMethod.simple;
  String? _accountId;
  DateTime? _start;
  DateTime? _maturity;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.depositId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.depositId;
    if (id == null) {
      final now = DateTime.now();
      setState(() {
        _start = DateTime(now.year, now.month, now.day);
        _maturity = DateTime(now.year + 1, now.month, now.day);
        _loading = false;
      });
      return;
    }
    final deposit = await ref.read(timeDepositsDaoProvider).byId(id);
    if (!mounted) return;
    if (deposit == null || deposit.isMatured) {
      context.pop();
      return;
    }
    setState(() {
      _label.text = deposit.label;
      _amount.text = (deposit.principalCents / 100)
          .toStringAsFixed(2)
          .replaceFirst('.00', '');
      _rate.text = deposit.interestRate == 0
          ? '0'
          : (deposit.interestRate * 100).toStringAsFixed(2);
      _method = InterestMethod.fromKey(deposit.interestMethod);
      _accountId = deposit.accountId;
      _start = DateTime.fromMillisecondsSinceEpoch(deposit.startDate);
      _maturity = DateTime.fromMillisecondsSinceEpoch(deposit.maturityDate);
      _loading = false;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _maturity;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _maturity = picked;
        }
      });
    }
  }

  int? _previewValue(int amountCents) {
    final rate = double.tryParse(_rate.text.trim());
    if (rate == null || _start == null || _maturity == null) {
      return null;
    }
    return TimeDepositService.maturityValue(
      principalCents: amountCents,
      annualRate: rate / 100,
      days: TimeDepositService.daysBetween(_start!, _maturity!),
      method: _method,
    );
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final amountCents = parseMoneyCents(_amount.text);
    if (amountCents == null) {
      setState(() => _error = 'Enter a valid principal amount.');
      return;
    }
    final percent = double.tryParse(_rate.text.trim());
    if (percent == null || percent < 0) {
      setState(() => _error = 'Enter a rate of 0 or more.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick the account holding the principal.');
      return;
    }
    if (_start == null || _maturity == null || !_maturity!.isAfter(_start!)) {
      setState(() => _error = 'Maturity date must be after the start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final service = ref.read(timeDepositServiceProvider);
    try {
      if (_isEdit) {
        final deposit = await ref.read(timeDepositsDaoProvider).byId(widget.depositId!);
        if (deposit == null || deposit.isMatured) {
          if (mounted) context.pop();
          return;
        }
        await service.update(
          deposit,
          label: label,
          principalCents: amountCents,
          annualRate: percent / 100,
          method: _method,
          start: _start!,
          maturity: _maturity!,
        );
      } else {
        await service.create(
          accountId: _accountId!,
          label: label,
          principalCents: amountCents,
          annualRate: percent / 100,
          method: _method,
          start: _start!,
          maturity: _maturity!,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = CurrencyScope.of(context);
    final accounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
            .where((a) => !a.isArchived)
            .toList();
    final amountCents = parseMoneyCents(_amount.text);
    final preview = amountCents == null ? null : _previewValue(amountCents);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit time deposit' : 'New time deposit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _label,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. 1-yr BPI TD',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomDropdownButton2<String?>(
                    hint: 'Account',
                    dropdownItems: [
                      for (final a in accounts) a.id,
                    ],
                    itemLabel: (id) =>
                        accounts.firstWhere((a) => a.id == id).name,
                    initialValue: _accountId,
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Principal amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rate,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Annual rate (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomDropdownButton2<InterestMethod>(
                          hint: 'Interest',
                          dropdownItems: [
                            for (final m in InterestMethod.values) m,
                          ],
                          itemLabel: (m) => m.label,
                          initialValue: _method,
                          onChanged: (v) =>
                              setState(() => _method = v ?? _method),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: true),
                          icon: const Icon(Icons.play_arrow_outlined, size: 20),
                          label: Text(_start == null
                              ? 'Start date'
                              : 'Start: ${_short(_start!)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: false),
                          icon: const Icon(Icons.flag_outlined, size: 20),
                          label: Text(_maturity == null
                              ? 'Maturity date'
                              : 'Mature: ${_short(_maturity!)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (preview != null) ...[
                    Card(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                      child: ListTile(
                        leading: const Icon(Icons.savings_outlined),
                        title: const Text('Maturity value'),
                        subtitle: Text(
                          'Interest at maturity: +${formatMoney(preview - amountCents!, symbol: symbol)}',
                        ),
                        trailing: Text(
                          formatMoney(preview, symbol: symbol),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),
    );
  }

  static String _short(DateTime d) => '${d.month}/${d.day}/${d.year}';
}
