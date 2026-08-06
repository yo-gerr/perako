import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/savings_interest_service.dart';
import '../providers/savings_providers.dart';

/// Configures the interest rate, compounding schedule, and pause state of a
/// savings account. Saving upserts the [SavingsAccounts] row and seeds the
/// interest schedule for it.
class SavingsSettingsScreen extends ConsumerStatefulWidget {
  const SavingsSettingsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<SavingsSettingsScreen> createState() =>
      _SavingsSettingsScreenState();
}

class _SavingsSettingsScreenState
    extends ConsumerState<SavingsSettingsScreen> {
  final _rate = TextEditingController();
  CompoundingFrequency _frequency = CompoundingFrequency.monthly;
  int _creditDay = 1;
  bool _isPaused = false;
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  void _initFrom(SavingsAccount? savings) {
    if (_loaded || savings == null) return;
    _loaded = true;
    _rate.text =
        (savings.interestRate * 100).toStringAsFixed(savings.interestRate * 100 % 1 == 0 ? 0 : 2);
    _frequency = CompoundingFrequency.fromKey(savings.compoundingFrequency);
    _creditDay = savings.interestCreditDay;
    _isPaused = savings.isPaused;
  }

  Future<void> _save() async {
    final percent = double.tryParse(_rate.text.trim());
    if (percent == null || percent < 0) {
      setState(() => _error = 'Enter a rate of 0 or more.');
      return;
    }

    final dao = ref.read(savingsDaoProvider);
    final existing = await dao.byAccountId(widget.accountId);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await dao.upsert(SavingsAccountsCompanion(
      accountId: Value(widget.accountId),
      interestRate: Value(percent / 100),
      compoundingFrequency: Value(_frequency.name),
      interestCreditDay: Value(_creditDay),
      isPaused: Value(_isPaused),
      startDate: Value(existing?.startDate ?? nowMillis),
      updatedAt: Value(nowMillis),
      version: Value((existing?.version ?? 0) + 1),
    ));
    await ref
        .read(savingsInterestServiceProvider)
        .ensureSchedules();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Savings settings saved.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider(widget.accountId));
    final savings = ref.watch(savingsAccountProvider(widget.accountId)).value;
    _initFrom(savings);

    return Scaffold(
      appBar: AppBar(title: Text('Savings — ${_name(account)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Annual interest rate (%)',
              hintText: 'e.g. 5',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CompoundingFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(
              labelText: 'Compounding',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final f in CompoundingFrequency.values)
                DropdownMenuItem(value: f, child: Text(f.label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _frequency = v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _creditDay,
            decoration: const InputDecoration(
              labelText: 'Interest credit day',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var day = 1; day <= 28; day++)
                DropdownMenuItem(
                  value: day,
                  child: Text('Day $day'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _creditDay = v);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pause interest'),
            subtitle: const Text('Stop accruing interest until re-enabled.'),
            value: _isPaused,
            onChanged: (v) => setState(() => _isPaused = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static String _name(AsyncValue<Account?> account) =>
      account.valueOrNull?.name ?? 'Savings';
}
