import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/mp2_service.dart';
import '../providers/mp2_accounts_provider.dart';

class Mp2FormScreen extends ConsumerStatefulWidget {
  const Mp2FormScreen({super.key, this.mp2Id});

  final String? mp2Id;

  @override
  ConsumerState<Mp2FormScreen> createState() => _Mp2FormScreenState();
}

class _Mp2FormScreenState extends ConsumerState<Mp2FormScreen> {
  final _label = TextEditingController();
  final _rate = TextEditingController();
  String? _accountId;
  DateTime? _start;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.mp2Id != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _label.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.mp2Id;
    if (id == null) {
      final now = DateTime.now();
      setState(() {
        _start = DateTime(now.year, now.month, now.day);
        _loading = false;
      });
      return;
    }
    final mp2 = await ref.read(mp2DaoProvider).byId(id);
    if (!mounted) return;
    if (mp2 == null || mp2.isMatured) {
      context.pop();
      return;
    }
    setState(() {
      _label.text = mp2.label;
      _rate.text = mp2.dividendRate == 0
          ? '0'
          : (mp2.dividendRate * 100).toStringAsFixed(2);
      _accountId = mp2.accountId;
      _start = DateTime.fromMillisecondsSinceEpoch(mp2.startDate);
      _loading = false;
    });
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 30),
    );
    if (picked != null && mounted) {
      setState(() => _start = picked);
    }
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    final percent = double.tryParse(_rate.text.trim());
    if (percent == null || percent < 0) {
      setState(() => _error = 'Enter a dividend rate of 0 or more.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = 'Pick the account holding the MP2 funds.');
      return;
    }
    if (_start == null) {
      setState(() => _error = 'Pick a start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final service = ref.read(mp2ServiceProvider);
    try {
      if (_isEdit) {
        final mp2 = await ref.read(mp2DaoProvider).byId(widget.mp2Id!);
        if (mp2 == null || mp2.isMatured) {
          if (mounted) context.pop();
          return;
        }
        await service.update(
          mp2,
          label: label,
          dividendRate: percent / 100,
          startDate: _start!,
        );
      } else {
        await service.create(
          accountId: _accountId!,
          label: label,
          dividendRate: percent / 100,
          startDate: _start!,
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
    final accounts =
        (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
            .where((a) => !a.isArchived)
            .toList();

    return Scaffold(
      appBar:
          AppBar(title: Text(_isEdit ? 'Edit MP2 account' : 'New MP2 account')),
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
                      hintText: 'e.g. My MP2',
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
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Dividend rate (%) p.a.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.play_arrow_outlined, size: 20),
                    label: Text(_start == null
                        ? 'Start date'
                        : 'Start: ${_short(_start!)}'),
                  ),
                  const SizedBox(height: 4),
                  if (_start != null)
                    Text(
                      'Matures ${_short(Mp2Service.maturityDateFor(_start!))} '
                      '(5-year term)',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 16),
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
