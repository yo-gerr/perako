import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late int clock;

  // Deterministic ids for stable assertions.
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    engine = LedgerEngine(
      db: db,
      idGenerator: nextId,
      clock: () => clock,
    );
  });

  tearDown(() async {
    await db.close();
    idCounter = 0;
  });

  group('postTransaction', () {
    test('posts a balanced transfer and sums balances correctly', () async {
      // Move 50.00 from checking (credit) to savings (debit).
      await engine.postTransaction(
        description: 'Transfer to savings',
        on: DateTime.utc(2026, 1, 1),
        lines: const [
          LedgerLine(
              accountId: 'checking',
              type: EntryType.credit,
              amountCents: 5000),
          LedgerLine(
              accountId: 'savings', type: EntryType.debit, amountCents: 5000),
        ],
      );

      expect(await engine.getBalance('checking'), -5000);
      expect(await engine.getBalance('savings'), 5000);
      // Money is conserved across the ledger.
      expect(await engine.getNetWorth(), 0);
    });

    test('rejects an unbalanced transaction', () async {
      expect(
        () => engine.postTransaction(
          description: 'bad',
          lines: const [
            LedgerLine(
                accountId: 'a', type: EntryType.debit, amountCents: 100),
            LedgerLine(
                accountId: 'b', type: EntryType.credit, amountCents: 50),
          ],
        ),
        throwsA(isA<UnbalancedTransaction>()),
      );

      // Nothing was persisted.
      expect(await engine.getNetWorth(), 0);
    });

    test('rejects a transaction with no lines', () async {
      expect(
        () => engine.postTransaction(description: 'empty', lines: const []),
        throwsA(isA<EmptyTransactionException>()),
      );
    });

    test('rejects negative amounts', () async {
      expect(
        () => engine.postTransaction(
          description: 'neg',
          lines: const [
            LedgerLine(
                accountId: 'a', type: EntryType.debit, amountCents: -5),
            LedgerLine(
                accountId: 'b', type: EntryType.credit, amountCents: 5),
          ],
        ),
        throwsA(isA<NegativeAmountException>()),
      );
    });
  });

  group('getBalance', () {
    test('is zero before any entries', () async {
      expect(await engine.getBalance('missing'), 0);
    });

    test('respects asOf date boundary', () async {
      await engine.postTransaction(
        description: 'jan purchase',
        on: DateTime.utc(2026, 1, 31),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 1000),
          LedgerLine(
              accountId: 'income', type: EntryType.credit, amountCents: 1000),
        ],
      );
      await engine.postTransaction(
        description: 'feb purchase',
        on: DateTime.utc(2026, 2, 15),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 200),
          LedgerLine(
              accountId: 'expense', type: EntryType.credit, amountCents: 200),
        ],
      );

      // As of end of January, only the first entry counts.
      expect(
        await engine.getBalance('checking', asOf: DateTime.utc(2026, 1, 31)),
        1000,
      );
      expect(await engine.getBalance('checking'), 1200);
    });
  });

  group('getNetWorth', () {
    test('sums assets minus liabilities across real accounts', () async {
      final now = DateTime(2026, 1, 15).millisecondsSinceEpoch;
      final accountsDao = AccountsDao(db);
      for (final (id, type) in [
        ('checking', 'checking'),
        ('credit_card', 'creditCard'),
      ]) {
        await accountsDao.insertAccount(AccountsCompanion(
          id: Value(id),
          name: Value(id),
          type: Value(type),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(now),
          updatedAt: Value(now),
          version: const Value(1),
        ));
      }

      // An asset: salary deposited into checking.
      await engine.postTransaction(
        description: 'salary',
        on: DateTime.utc(2026, 1, 15),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 100000),
          LedgerLine(
              accountId: 'salary_income',
              type: EntryType.credit,
              amountCents: 100000),
        ],
      );
      // A liability: spending on a credit card.
      await engine.postTransaction(
        description: 'lunch',
        on: DateTime.utc(2026, 1, 15),
        lines: const [
          LedgerLine(
              accountId: 'expense', type: EntryType.debit, amountCents: 5000),
          LedgerLine(
              accountId: 'credit_card',
              type: EntryType.credit,
              amountCents: 5000),
        ],
      );

      // Assets (100000) minus liabilities (5000).
      expect(await engine.getNetWorth(), 95000);
    });
  });

  group('reverseTransaction', () {
    test('reverses a posting and restores balances', () async {
      final txId = await engine.postTransaction(
        description: 'rent',
        on: DateTime.utc(2026, 3, 1),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 10000),
          LedgerLine(
              accountId: 'expense', type: EntryType.credit, amountCents: 10000),
        ],
      );

      expect(await engine.getBalance('checking'), 10000);

      await engine.reverseTransaction(txId);

      // Reversed back to zero.
      expect(await engine.getBalance('checking'), 0);
      // The original entries are preserved.
      final entries = await LedgerDao(db).forTransaction(txId);
      expect(entries.length, 2);
    });
  });

  group('validateTransaction', () {
    test('accepts a balanced set', () {
      engine.validateTransaction(const [
        LedgerLine(accountId: 'a', type: EntryType.debit, amountCents: 10),
        LedgerLine(accountId: 'b', type: EntryType.credit, amountCents: 10),
      ]);
    });

    test('rejects unbalanced set', () {
      expect(
        () => engine.validateTransaction(const [
          LedgerLine(accountId: 'a', type: EntryType.debit, amountCents: 10),
          LedgerLine(accountId: 'b', type: EntryType.credit, amountCents: 9),
        ]),
        throwsA(isA<UnbalancedTransaction>()),
      );
    });
  });
}