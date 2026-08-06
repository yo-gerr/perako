import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../categories/domain/category_types.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../../domain/bill_service.dart';
import '../providers/bills_providers.dart';

class BillFormScreen extends ConsumerStatefulWidget {
  const BillFormScreen({super.key, this.billId});

  final String? billId;

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _day = TextEditingController();
  BillFrequency _frequency = BillFrequency.monthly;
  String? _accountId;
  String? _categoryId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.billId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.billId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final bill = await ref.read(billsDaoProvider).byId(id);
    if (!mounted) return;
    setState(() {
      if (bill != null) {
        _name.text = bill.name;
        _amount.text = (bill.amountCents / 100)
            .toStringAsFixed(2)
            .replaceFirst('.00', '');
        _frequency = BillFrequency.fromKey(bill.frequency);
        _accountId = bill.accountId;
        _categoryId = bill.categoryId;
        if (bill.dayOfMonth != null) {
          _day.text = bill.dayOfMonth.toString();
        }
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final amountCents = parseMoneyCents(_amount.text);
    if (amountCents == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick the account to pay from.');
      return;
    }
    int? dayOfMonth;
    if (_frequency != BillFrequency.weekly) {
      final day = int.tryParse(_day.text.trim());
      if (day == null || day < 1 || day > 31) {
        setState(() => _error = 'Enter a day of the month (1-31).');
        return;
      }
      dayOfMonth = day;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final dao = ref.read(billsDaoProvider);
    final service = ref.read(billServiceProvider);
    final now = DateTime.now();
    final accountId = _accountId!;

    try {
      if (_isEdit) {
        await dao.updateBill(BillsCompanion(
          id: Value(widget.billId!),
          name: Value(name),
          amountCents: Value(amountCents),
          frequency: Value(_frequency.name),
          dayOfMonth: Value(dayOfMonth),
          accountId: Value(accountId),
          categoryId: Value(_categoryId),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ));
      } else {
        final nextDue = service.initialDueDate(_frequency, dayOfMonth);
        await dao.insert(BillsCompanion(
          id: Value('bil_${DateTime.now().microsecondsSinceEpoch}'),
          name: Value(name),
          amountCents: Value(amountCents),
          frequency: Value(_frequency.name),
          dayOfMonth: Value(dayOfMonth),
          accountId: Value(accountId),
          categoryId: Value(_categoryId),
          nextDueDate: Value(nextDue.millisecondsSinceEpoch),
          createdAt: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
          version: const Value(1),
        ));
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
    final expenseCategories =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
            .where((c) => CategoryType.fromKey(c.type) == CategoryType.expense)
            .toList();
    final accounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
            .where((a) => !a.isArchived)
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit bill' : 'New bill')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Pay from account',
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
                  DropdownButtonFormField<String?>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      for (final c in expenseCategories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BillFrequency>(
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final f in BillFrequency.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (v) => setState(() => _frequency = v ?? _frequency),
                  ),
                  if (_frequency != BillFrequency.weekly) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _day,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Day of the month',
                        hintText: 'e.g. 15',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),
    );
  }
}
