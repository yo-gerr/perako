import 'package:async/async.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/categories_dao.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/transaction_posting.dart';

/// A transaction enriched for display: primary account, signed amount, and
/// (for transfers) the destination.
class TransactionRow {
  const TransactionRow({
    required this.transaction,
    required this.type,
    required this.signedAmountCents,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
  });

  final Transaction transaction;
  final TxType type;

  /// Positive for money flowing into the primary account, negative otherwise.
  final int signedAmountCents;
  final String accountName;
  final String? toAccountName;
  final String? categoryName;
}

/// Recent transactions enriched with account/category names and a signed
/// amount. Recomputes whenever transactions, ledger entries, or accounts
/// change.
final transactionsProvider = StreamProvider<List<TransactionRow>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final txDao = ref.watch(transactionsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    txDao.watchRecent(limit: 200),
    ledgerDao.changes(),
    accountsDao.watchActive(),
  ]);

  await for (final _ in trigger) {
    final transactions = await txDao.recent(limit: 200);
    if (transactions.isEmpty) {
      yield const [];
      continue;
    }

    final accounts = await accountsDao.all();
    final accountsById = {for (final a in accounts) a.id: a};
    final categories = await CategoriesDao(db).all();
    final categoriesById = {for (final c in categories) c.id: c};

    final txIds = [for (final t in transactions) t.id];
    final q = db.select(db.ledgerEntries)
      ..where((t) => t.transactionId.isIn(txIds) & t.deletedAt.isNull());
    final entries = await q.get();

    final byTx = <String, List<LedgerEntry>>{};
    for (final e in entries) {
      byTx.putIfAbsent(e.transactionId, () => []).add(e);
    }

    final rows = <TransactionRow>[];
    for (final t in transactions) {
      final txEntries = byTx[t.id] ?? const <LedgerEntry>[];
      if (txEntries.isEmpty) continue;

      final amount =
          txEntries.fold<int>(0, (sum, e) => sum + e.amount) ~/ 2;
      final real = txEntries
          .where((e) => accountsById.containsKey(e.accountId))
          .toList();
      if (real.isEmpty) continue;

      LedgerEntry? corpus;
      for (final e in txEntries) {
        if (!accountsById.containsKey(e.accountId)) {
          corpus = e;
          break;
        }
      }
      final categoryName = (corpus?.categoryId != null &&
              categoriesById.containsKey(corpus!.categoryId))
          ? categoriesById[corpus.categoryId]!.name
          : null;

      if (real.length == 2) {
        final credit = real.firstWhere((e) => e.type == 'credit');
        final debit = real.firstWhere((e) => e.type == 'debit');
        rows.add(TransactionRow(
          transaction: t,
          type: TxType.transfer,
          signedAmountCents: -amount,
          accountName: accountsById[credit.accountId]!.name,
          toAccountName: accountsById[debit.accountId]!.name,
        ));
      } else {
        final primary = real.first;
        final isInflow = primary.type == 'debit';
        rows.add(TransactionRow(
          transaction: t,
          type: isInflow ? TxType.income : TxType.expense,
          signedAmountCents: isInflow ? amount : -amount,
          accountName: accountsById[primary.accountId]!.name,
          categoryName: categoryName,
        ));
      }
    }

    yield rows;
  }
});

/// A single transaction by id, or null.
final transactionProvider = FutureProvider.family<Transaction?, String>(
    (ref, id) => ref.watch(transactionsDaoProvider).byId(id));

/// Ledger entries for a single transaction.
final transactionEntriesProvider =
    FutureProvider.family<List<LedgerEntry>, String>((ref, id) {
  return ref.watch(ledgerDaoProvider).forTransaction(id);
});
