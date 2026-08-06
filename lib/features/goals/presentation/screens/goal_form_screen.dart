import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/goal_service.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  GoalType _type = GoalType.savings;
  DateTime? _targetDate;
  String? _fundingAccountId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.goalId != null;

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
    final id = widget.goalId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final goal = await ref.read(goalsDaoProvider).byId(id);
    if (!mounted) return;
    setState(() {
      if (goal != null) {
        _name.text = goal.name;
        _amount.text = (goal.targetAmountCents / 100)
            .toStringAsFixed(2)
            .replaceFirst('.00', '');
        _type = GoalType.fromKey(goal.type);
        _targetDate = goal.targetDate == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(goal.targetDate!);
        _fundingAccountId = goal.fundingAccountId;
      }
      _loading = false;
    });
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 1, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
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
    if (_fundingAccountId == null) {
      setState(() => _error = 'Pick the account to fund the goal.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final dao = ref.read(goalsDaoProvider);
    final now = DateTime.now();
    final fundingAccountId = _fundingAccountId!;

    try {
      if (_isEdit) {
        await dao.updateGoal(GoalsCompanion(
          id: Value(widget.goalId!),
          name: Value(name),
          type: Value(_type.name),
          targetAmountCents: Value(amountCents),
          targetDate: Value(_targetDate?.millisecondsSinceEpoch),
          fundingAccountId: Value(fundingAccountId),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ));
      } else {
        await dao.insert(GoalsCompanion(
          id: Value('goal_${DateTime.now().microsecondsSinceEpoch}'),
          name: Value(name),
          type: Value(_type.name),
          targetAmountCents: Value(amountCents),
          targetDate: Value(_targetDate?.millisecondsSinceEpoch),
          fundingAccountId: Value(fundingAccountId),
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
    final theme = Theme.of(context);
    final accounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
            .where((a) => !a.isArchived)
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit goal' : 'New goal')),
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
                  DropdownButtonFormField<GoalType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in GoalType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _fundingAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Fund from account',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select account')),
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) =>
                        setState(() => _fundingAccountId = v),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickTargetDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _targetDate == null
                          ? 'Target date (optional)'
                          : 'Target: ${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}',
                    ),
                  ),
                  if (_targetDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _targetDate = null),
                        child: const Text('Clear date'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
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
}
