import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_dropdown_button2.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../categories/domain/category_types.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../../domain/budget_service.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key, this.budgetId});

  final String? budgetId;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  BudgetPeriod _period = BudgetPeriod.monthly;
  String? _categoryId;
  String? _accountId;
  bool _rollover = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.budgetId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.budgetId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final budget = await ref.read(budgetsDaoProvider).byId(id);
    if (!mounted) return;
    setState(() {
      if (budget != null) {
        _name.text = budget.name;
        _amount.text =
            (budget.amountCents / 100).toStringAsFixed(2).replaceFirst('.00', '');
        _period = BudgetPeriod.fromKey(budget.period);
        _categoryId = budget.categoryId;
        _accountId = budget.accountId;
        _rollover = budget.rollover;
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
    if (_categoryId == null && _accountId == null) {
      setState(() => _error = 'Pick a category or an account to track.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final dao = ref.read(budgetsDaoProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_isEdit) {
        await dao.updateBudget(BudgetsCompanion(
          id: Value(widget.budgetId!),
          name: Value(name),
          amountCents: Value(amountCents),
          period: Value(_period.name),
          categoryId: Value(_categoryId),
          accountId: Value(_accountId),
          rollover: Value(_rollover),
          updatedAt: Value(now),
        ));
      } else {
        await dao.insert(BudgetsCompanion(
          id: Value('bgt_${DateTime.now().microsecondsSinceEpoch}'),
          name: Value(name),
          amountCents: Value(amountCents),
          period: Value(_period.name),
          categoryId: Value(_categoryId),
          accountId: Value(_accountId),
          rollover: Value(_rollover),
          createdAt: Value(now),
          updatedAt: Value(now),
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
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[]);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit budget' : 'New budget')),
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
                  CustomDropdownButton2<BudgetPeriod>(
                    hint: 'Period',
                    dropdownItems: [for (final p in BudgetPeriod.values) p],
                    itemLabel: (p) => p.label,
                    initialValue: _period,
                    onChanged: (v) => setState(() => _period = v ?? _period),
                  ),
                  const SizedBox(height: 16),
                  CustomDropdownButton2<String?>(
                    hint: 'Category (optional)',
                    dropdownItems: [
                      for (final c in expenseCategories) c.id,
                    ],
                    itemLabel: (id) => expenseCategories
                        .firstWhere((c) => c.id == id)
                        .name,
                    initialValue: _categoryId,
                    onChanged: (v) =>
                        setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 16),
                  CustomDropdownButton2<String?>(
                    hint: 'Account (optional)',
                    dropdownItems: [
                      for (final a in accounts)
                        if (!a.isArchived) a.id,
                    ],
                    itemLabel: (id) =>
                        accounts.firstWhere((a) => a.id == id).name,
                    initialValue: _accountId,
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Roll over unused budget'),
                    subtitle: const Text(
                        'Carry a positive remainder into the next period'),
                    value: _rollover,
                    onChanged: (v) => setState(() => _rollover = v),
                  ),
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
