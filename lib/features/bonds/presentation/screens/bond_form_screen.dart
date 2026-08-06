import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/bond_service.dart';
import '../providers/bonds_providers.dart';

class BondFormScreen extends ConsumerStatefulWidget {
  const BondFormScreen({super.key, this.bondId});

  final String? bondId;

  @override
  ConsumerState<BondFormScreen> createState() => _BondFormScreenState();
}

class _BondFormScreenState extends ConsumerState<BondFormScreen> {
  final _label = TextEditingController();
  final _faceValue = TextEditingController();
  final _rate = TextEditingController();
  CouponSchedule _schedule = CouponSchedule.quarterly;
  String? _accountId;
  DateTime? _start;
  DateTime? _maturity;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.bondId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _label.dispose();
    _faceValue.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.bondId;
    if (id == null) {
      final now = DateTime.now();
      setState(() {
        _start = DateTime(now.year, now.month, now.day);
        _maturity = DateTime(now.year + 5, now.month, now.day);
        _loading = false;
      });
      return;
    }
    final bond = await ref.read(bondsDaoProvider).byId(id);
    if (!mounted) return;
    if (bond == null || bond.isMatured) {
      context.pop();
      return;
    }
    setState(() {
      _label.text = bond.label;
      _faceValue.text = (bond.faceValueCents / 100)
          .toStringAsFixed(2)
          .replaceFirst('.00', '');
      _rate.text = bond.couponRate == 0
          ? '0'
          : (bond.couponRate * 100).toStringAsFixed(2);
      _schedule = CouponSchedule.fromKey(bond.couponSchedule);
      _accountId = bond.accountId;
      _start = DateTime.fromMillisecondsSinceEpoch(bond.startDate);
      _maturity = DateTime.fromMillisecondsSinceEpoch(bond.maturityDate);
      _loading = false;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _maturity;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 40),
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

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final faceValueCents = parseMoneyCents(_faceValue.text);
    if (faceValueCents == null || faceValueCents <= 0) {
      setState(() => _error = 'Enter a valid face value.');
      return;
    }
    final percent = double.tryParse(_rate.text.trim());
    if (percent == null || percent < 0) {
      setState(() => _error = 'Enter a coupon rate of 0 or more.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick the account holding the bond.');
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

    final service = ref.read(bondServiceProvider);
    try {
      if (_isEdit) {
        final bond = await ref.read(bondsDaoProvider).byId(widget.bondId!);
        if (bond == null || bond.isMatured) {
          if (mounted) context.pop();
          return;
        }
        await service.update(
          bond,
          label: label,
          faceValueCents: faceValueCents,
          couponRate: percent / 100,
          schedule: _schedule,
          startDate: _start!,
          maturityDate: _maturity!,
        );
      } else {
        await service.create(
          accountId: _accountId!,
          label: label,
          faceValueCents: faceValueCents,
          couponRate: percent / 100,
          schedule: _schedule,
          startDate: _start!,
          maturityDate: _maturity!,
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
    final faceValueCents = parseMoneyCents(_faceValue.text);
    final rate = double.tryParse(_rate.text.trim());
    final perCoupon = (faceValueCents != null && rate != null)
        ? BondService.couponAmount(
            faceValueCents: faceValueCents,
            couponRate: rate / 100,
            schedule: _schedule,
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit bond' : 'New bond')),
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
                      hintText: 'e.g. 5-yr RTB',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select account')),
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _faceValue,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Face value',
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
                            labelText: 'Coupon rate (%) p.a.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<CouponSchedule>(
                          initialValue: _schedule,
                          decoration: const InputDecoration(
                            labelText: 'Schedule',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final s in CouponSchedule.values)
                              DropdownMenuItem(value: s, child: Text(s.label)),
                          ],
                          onChanged: (v) =>
                              setState(() => _schedule = v ?? _schedule),
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
                  if (perCoupon != null && _start != null) ...[
                    Card(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.35),
                      child: ListTile(
                        leading: const Icon(Icons.savings_outlined),
                        title: const Text('Coupon per period'),
                        subtitle: Text(
                          '${_schedule.label} at '
                          '${(rate! * 100).toStringAsFixed(2)}% p.a.',
                        ),
                        trailing: Text(
                          formatMoney(perCoupon, symbol: symbol),
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
