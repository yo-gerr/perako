import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../../domain/transaction_posting.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  /// When set, the form edits (reverse + repost) the existing transaction
  /// instead of creating a new one.
  final String? transactionId;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  TxType _type = TxType.expense;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _loading = false;
  String? _error;

  bool get _editing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Reconstructs the form from the existing transaction and its ledger
  /// entries so the user edits a faithful picture of what was posted.
  Future<void> _loadExisting() async {
    final id = widget.transactionId!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tx = await ref.read(transactionsDaoProvider).byId(id);
      final entries = await ref.read(ledgerDaoProvider).forTransaction(id);
      if (!mounted) return;
      if (tx == null) {
        setState(() {
          _loading = false;
          _error = 'Transaction not found.';
        });
        return;
      }

      final amount = entries.fold<int>(0, (sum, e) => sum + e.amount) ~/ 2;
      final real = entries
          .where((e) =>
              e.accountId != LedgerConstants.counterpartyIncome &&
              e.accountId != LedgerConstants.counterpartyExpense)
          .toList();
      final corpus = entries
          .where((e) =>
              e.accountId == LedgerConstants.counterpartyIncome ||
              e.accountId == LedgerConstants.counterpartyExpense)
          .toList();

      setState(() {
        _loading = false;
        _date = DateTime.fromMillisecondsSinceEpoch(tx.date).toLocal();
        _amount.text = (amount / 100).toStringAsFixed(2);
        _notes.text = tx.notes ?? '';
        if (real.length == 2) {
          _type = TxType.transfer;
          final credit = real.firstWhere((e) => e.type == 'credit');
          final debit = real.firstWhere((e) => e.type == 'debit');
          _accountId = credit.accountId;
          _toAccountId = debit.accountId;
          _categoryId = null;
        } else if (real.isNotEmpty) {
          final primary = real.first;
          _type = primary.type == 'debit' ? TxType.income : TxType.expense;
          _accountId = primary.accountId;
          _toAccountId = null;
          _categoryId = corpus.isEmpty ? null : corpus.first.categoryId;
        } else {
          _error = 'Transaction has no account entries to edit.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _save() async {
    final amountCents = _parseAmountCents(_amount.text);
    if (_accountId == null) {
      setState(() => _error = 'Choose an account.');
      return;
    }
    if (_type == TxType.transfer && _toAccountId == null) {
      setState(() => _error = 'Choose a destination account.');
      return;
    }
    if (_type == TxType.transfer && _toAccountId == _accountId) {
      setState(() => _error = 'Source and destination must differ.');
      return;
    }
    if (amountCents == null || amountCents <= 0) {
      setState(() => _error = 'Enter a positive amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final engine = ref.read(ledgerEngineProvider);
    final description = _notes.text.trim().isNotEmpty
        ? _notes.text.trim()
        : _defaultDescription();
    final notes = _notes.text.trim().isNotEmpty ? _notes.text.trim() : null;
    final lines = buildLedgerLines(
      type: _type,
      accountId: _accountId!,
      toAccountId: _type == TxType.transfer ? _toAccountId : null,
      categoryId: _type == TxType.transfer ? null : _categoryId,
      amountCents: amountCents,
    );

    try {
      if (_editing) {
        await engine.replaceTransaction(
          transactionId: widget.transactionId!,
          description: description,
          notes: notes,
          on: _date,
          lines: lines,
        );
      } else {
        await engine.postTransaction(
          description: description,
          notes: notes,
          on: _date,
          lines: lines,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _defaultDescription() => switch (_type) {
        TxType.income => 'Income',
        TxType.expense => 'Expense',
        TxType.transfer => 'Transfer',
      };

  int? _parseAmountCents(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
          title: Text(_editing ? 'Edit transaction' : 'New transaction')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<TxType>(
                    segments: const [
                      ButtonSegment(
                          value: TxType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.south_west)),
                      ButtonSegment(
                          value: TxType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.north_east)),
                      ButtonSegment(
                          value: TxType.transfer,
                          label: Text('Transfer'),
                          icon: Icon(Icons.swap_horiz)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  if (_type == TxType.transfer) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _toAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final a in accounts)
                          if (a.id != _accountId)
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      onChanged: (v) => setState(() => _toAccountId = v),
                    ),
                  ] else ...[
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
                        for (final c in categories)
                          if (c.type == _type.name)
                            DropdownMenuItem(
                                value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₱)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Date'),
                    subtitle: Text(_date.toLocal().toString().split(' ')[0]),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
