import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/categories_dao.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';
import 'package:perako/features/transactions/presentation/providers/transactions_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

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
    await CategoriesDao(db).insertCategory(CategoriesCompanion(
      id: const Value('cat_salary'),
      name: const Value('Salary'),
      type: const Value('income'),
      color: const Value('green'),
      icon: const Value('category'),
      isArchived: const Value(false),
      updatedAt: Value(now),
      version: const Value(1),
    ));

    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<TransactionRow> postAndRead({
    required TxType type,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    int amountCents = 10000,
    String description = 'tx',
  }) async {
    final engine = LedgerEngine(db: db);
    await engine.postTransaction(
      description: description,
      on: DateTime.utc(2026, 1, 15),
      lines: buildLedgerLines(
        type: type,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        amountCents: amountCents,
      ),
    );
    final rows = await container.read(transactionsProvider.future);
    return rows.firstWhere((r) => r.transaction.description == description);
  }

  test('income is enriched with account, category, and signed amount', () async {
    final row = await postAndRead(
      type: TxType.income,
      accountId: 'acc_cash',
      categoryId: 'cat_salary',
      description: 'January salary',
    );

    expect(row.type, TxType.income);
    expect(row.signedAmountCents, 10000);
    expect(row.accountName, 'Cash');
    expect(row.categoryName, 'Salary');
    expect(row.toAccountName, isNull);
  });

  test('expense signs the amount negative', () async {
    final row = await postAndRead(
      type: TxType.expense,
      accountId: 'acc_cash',
      description: 'Lunch',
    );

    expect(row.type, TxType.expense);
    expect(row.signedAmountCents, -10000);
    expect(row.accountName, 'Cash');
  });

  test('transfer exposes source and destination', () async {
    final row = await postAndRead(
      type: TxType.transfer,
      accountId: 'acc_cash',
      toAccountId: 'acc_savings',
      description: 'Save up',
    );

    expect(row.type, TxType.transfer);
    // Money left the source account.
    expect(row.signedAmountCents, -10000);
    expect(row.accountName, 'Cash');
    expect(row.toAccountName, 'Savings');
    expect(row.categoryName, isNull);
  });
}
