import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/core/database/daos/transactions_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late TransactionsDao transactionsDao;
  late LedgerDao ledgerDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = LedgerEngine(db: db);
    transactionsDao = TransactionsDao(db);
    ledgerDao = LedgerDao(db);

    final now = DateTime(2026, 1, 15).millisecondsSinceEpoch;
    await AccountsDao(db).insertAccount(AccountsCompanion(
      id: const Value('acc_cash'),
      name: const Value('Cash'),
      type: const Value('cash'),
      currency: const Value('PHP'),
      color: const Value('teal'),
      icon: const Value('wallet'),
      isArchived: const Value(false),
      openingDate: Value(now),
      updatedAt: Value(now),
      version: const Value(1),
    ));
    await AccountsDao(db).insertAccount(AccountsCompanion(
      id: const Value('acc_savings'),
      name: const Value('Savings'),
      type: const Value('savings'),
      currency: const Value('PHP'),
      color: const Value('blue'),
      icon: const Value('wallet'),
      isArchived: const Value(false),
      openingDate: Value(now),
      updatedAt: Value(now),
      version: const Value(1),
    ));

    addTearDown(db.close);
  });

  Future<String> post(
    TxType type, {
    required String accountId,
    String? toAccountId,
    String? categoryId,
    int amountCents = 5000,
    String description = 'Original',
    DateTime? on,
  }) {
    return engine.postTransaction(
      description: description,
      on: on ?? DateTime.utc(2026, 1, 15),
      lines: buildLedgerLines(
        type: type,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        amountCents: amountCents,
      ),
    );
  }

  test('replaceTransaction nets the balance to the new amount', () async {
    final originalId = await post(TxType.expense, accountId: 'acc_cash');

    await engine.replaceTransaction(
      transactionId: originalId,
      description: 'Corrected lunch',
      on: DateTime.utc(2026, 1, 16),
      lines: buildLedgerLines(
        type: TxType.expense,
        accountId: 'acc_cash',
        amountCents: 3000,
      ),
    );

    // Net effect on the account: -5000 (original) +5000 (reversal) -3000 (new).
    expect(await engine.getBalance('acc_cash'), -3000);
  });

  test('replaceTransaction preserves the audit trail', () async {
    final originalId = await post(TxType.expense, accountId: 'acc_cash');

    final newId = await engine.replaceTransaction(
      transactionId: originalId,
      description: 'Corrected lunch',
      lines: buildLedgerLines(
        type: TxType.expense,
        accountId: 'acc_cash',
        amountCents: 3000,
      ),
    );

    expect(newId, isNot(originalId));

    // Original transaction and its entries still exist, untouched.
    final original = await transactionsDao.byId(originalId);
    expect(original, isNotNull);
    final originalEntries = await ledgerDao.forTransaction(originalId);
    expect(originalEntries, hasLength(2));

    // A reversal was posted referencing the original.
    final all = await transactionsDao.recent(limit: 10);
    final reversal =
        all.firstWhere((t) => t.description == 'Reversal of $originalId');
    final reversalEntries = await ledgerDao.forTransaction(reversal.id);
    expect(reversalEntries, hasLength(2));

    // Reversal lines mirror the original directions.
    final orig = originalEntries.first;
    final rev = reversalEntries.first;
    expect(rev.accountId, orig.accountId);
    expect(rev.amount, orig.amount);
    expect(rev.type, isNot(orig.type));
  });

  test('replaceTransaction can change type (expense to transfer)', () async {
    final originalId = await post(TxType.expense, accountId: 'acc_cash');

    await engine.replaceTransaction(
      transactionId: originalId,
      description: 'Moved money instead',
      lines: buildLedgerLines(
        type: TxType.transfer,
        accountId: 'acc_cash',
        toAccountId: 'acc_savings',
        amountCents: 5000,
      ),
    );

    // Reversal returned the 5000 to cash, transfer moved it to savings.
    expect(await engine.getBalance('acc_cash'), -5000);
    expect(await engine.getBalance('acc_savings'), 5000);
  });

  test('replaceTransaction is atomic on reversal of a missing id', () async {
    await expectLater(
      engine.replaceTransaction(
        transactionId: 'missing',
        description: 'Nope',
        lines: buildLedgerLines(
          type: TxType.expense,
          accountId: 'acc_cash',
          amountCents: 100,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    // Nothing was posted for the failed edit.
    expect(await engine.getBalance('acc_cash'), 0);
    expect(await transactionsDao.recent(limit: 10), isEmpty);
  });
}
