import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';

/// All active (non-archived) accounts, newest first.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountsDaoProvider).watchActive();
});

/// A single account by id, or null.
final accountProvider = FutureProvider.family<Account?, String>((ref, id) {
  return ref.watch(accountsDaoProvider).byId(id);
});

/// The current derived balance (integer cents) for an account.
final accountBalanceProvider = FutureProvider.family<int, String>((ref, id) {
  return ref.watch(ledgerEngineProvider).getBalance(id);
});

/// Ledger entries belonging to an account, newest first.
final accountEntriesProvider =
    FutureProvider.family<List<LedgerEntry>, String>((ref, id) {
  return ref.watch(ledgerDaoProvider).entriesForAccount(id);
});
