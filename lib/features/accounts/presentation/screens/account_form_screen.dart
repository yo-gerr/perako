import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../ledger/domain/ledger_engine.dart';
import '../account_style.dart';
import '../../domain/account_types.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId});

  /// When set, the form edits the existing account instead of creating one.
  final String? accountId;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  AccountType _type = AccountType.checking;
  String _color = 'teal';
  String _icon = 'wallet';
  DateTime _openingDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = widget.accountId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final account = await ref.read(accountsDaoProvider).byId(id);
    if (!mounted) return;
    setState(() {
      if (account != null) {
        _name.text = account.name;
        _type = AccountType.fromKey(account.type);
        _color = account.color;
        _icon = account.icon;
        _openingDate =
            DateTime.fromMillisecondsSinceEpoch(account.openingDate);
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  int? _parseAmountCents(String raw) {
    final trimmed = raw.trim().replaceAll(',', '');
    final value = double.tryParse(trimmed);
    if (value == null || value == 0) return null;
    return (value * 100).round();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final dao = ref.read(accountsDaoProvider);
    final engine = ref.read(ledgerEngineProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_isEdit) {
        await dao.updateAccount(
          AccountsCompanion(
            id: Value(widget.accountId!),
            name: Value(name),
            type: Value(_type.key),
            color: Value(_color),
            icon: Value(_icon),
            updatedAt: Value(now),
          ),
        );
      } else {
        final id =
            'acc_${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}';
        final openingCents = _parseAmountCents(_opening.text) ?? 0;

        await dao.insertAccount(AccountsCompanion(
          id: Value(id),
          name: Value(name),
          type: Value(_type.key),
          currency: const Value('PHP'),
          color: Value(_color),
          icon: Value(_icon),
          isArchived: const Value(false),
          openingDate: Value(_openingDate.millisecondsSinceEpoch),
          updatedAt: Value(now),
          version: const Value(1),
        ));

        if (openingCents != 0) {
          final lines = openingCents > 0
              ? [
                  LedgerLine(
                      accountId: id,
                      type: EntryType.debit,
                      amountCents: openingCents),
                  LedgerLine(
                      accountId: LedgerConstants.counterpartyIncome,
                      type: EntryType.credit,
                      amountCents: openingCents),
                ]
              : [
                  LedgerLine(
                      accountId: id,
                      type: EntryType.credit,
                      amountCents: openingCents.abs()),
                  LedgerLine(
                      accountId: LedgerConstants.counterpartyExpense,
                      type: EntryType.debit,
                      amountCents: openingCents.abs()),
                ];
          await engine.postTransaction(
            description: 'Opening balance',
            on: _openingDate,
            lines: lines,
          );
        }
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit account' : 'New account')),
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
                  DropdownButtonFormField<AccountType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in AccountType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 16),
                  _ColorSelector(
                    selected: _color,
                    onChanged: (c) => setState(() => _color = c),
                  ),
                  const SizedBox(height: 16),
                  _IconSelector(
                    selected: _icon,
                    onChanged: (i) => setState(() => _icon = i),
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _opening,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Opening balance (₱)',
                        helperText: 'Optional. Negative for an owed balance.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: const Text('Opening date'),
                      subtitle: Text(_openingDate.toLocal().toString().split(
                              ' ')[0]),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _openingDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _openingDate = picked);
                        }
                      },
                    ),
                  ],
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
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final c in colorChoices)
          InkWell(
            onTap: () => onChanged(c),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorFromName(c),
                shape: BoxShape.circle,
                border: selected == c
                    ? Border.all(
                        width: 3, color: Theme.of(context).colorScheme.onSurface)
                    : null,
              ),
              child: selected == c
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _IconSelector extends StatelessWidget {
  const _IconSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final i in iconChoices)
          ChoiceChip(
            avatar: Icon(iconFromName(i), size: 20),
            label: const SizedBox.shrink(),
            selected: selected == i,
            onSelected: (_) => onChanged(i),
          ),
      ],
    );
  }
}
