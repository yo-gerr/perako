import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/categories_dao.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';
import 'package:perako/features/transactions/presentation/providers/transactions_providers.dart';

/// Headless end-to-end smoke: seed accounts, post income/expense/transfer, and
/// assert every derived view (balances, net worth, cash flow, transaction rows)
/// agrees. Covers roadmap item 1.8.
void main() {
  test('income, expense, and transfer flow through every derived view',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime.now();
    final nowMillis = now.millisecondsSinceEpoch;
    final accountsDao = AccountsDao(db);
    await accountsDao.insertAccount(AccountsCompanion(
      id: const Value('acc_cash'),
      name: const Value('Cash'),
      type: const Value('cash'),
      currency: const Value('PHP'),
      color: const Value('teal'),
      icon: const Value('wallet'),
      isArchived: const Value(false),
      openingDate: Value(nowMillis),
      updatedAt: Value(nowMillis),
      version: const Value(1),
    ));
    await accountsDao.insertAccount(AccountsCompanion(
      id: const Value('acc_savings'),
      name: const Value('Savings'),
      type: const Value('savings'),
      currency: const Value('PHP'),
      color: const Value('blue'),
      icon: const Value('wallet'),
      isArchived: const Value(false),
      openingDate: Value(nowMillis),
      updatedAt: Value(nowMillis),
      version: const Value(1),
    ));
    final categoriesDao = CategoriesDao(db);
    await categoriesDao.insertCategory(CategoriesCompanion(
      id: const Value('cat_salary'),
      name: const Value('Salary'),
      type: const Value('income'),
      color: const Value('green'),
      icon: const Value('category'),
      isArchived: const Value(false),
      updatedAt: Value(nowMillis),
      version: const Value(1),
    ));
    await categoriesDao.insertCategory(CategoriesCompanion(
      id: const Value('cat_food'),
      name: const Value('Food'),
      type: const Value('expense'),
      color: const Value('orange'),
      icon: const Value('restaurant'),
      isArchived: const Value(false),
      updatedAt: Value(nowMillis),
      version: const Value(1),
    ));

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final engine = LedgerEngine(db: db);
    await engine.postTransaction(
      description: 'January salary',
      on: now,
      lines: buildLedgerLines(
        type: TxType.income,
        accountId: 'acc_cash',
        categoryId: 'cat_salary',
        amountCents: 100000,
      ),
    );
    await engine.postTransaction(
      description: 'Groceries',
      on: now,
      lines: buildLedgerLines(
        type: TxType.expense,
        accountId: 'acc_cash',
        categoryId: 'cat_food',
        amountCents: 25000,
      ),
    );
    await engine.postTransaction(
      description: 'Save up',
      on: now,
      lines: buildLedgerLines(
        type: TxType.transfer,
        accountId: 'acc_cash',
        toAccountId: 'acc_savings',
        amountCents: 20000,
      ),
    );

    // Account balances.
    expect(await engine.getBalance('acc_cash'), 55000);
    expect(await engine.getBalance('acc_savings'), 20000);

    // Dashboard net worth and per-account rows.
    final dashboard = await container.read(dashboardProvider.future);
    expect(dashboard.netWorthCents, 75000);
    final balances = {
      for (final row in dashboard.rows) row.account.id: row.balanceCents,
    };
    expect(balances, {'acc_cash': 55000, 'acc_savings': 20000});

    // Income/expense for the current month.
    final (income, expense) =
        await container.read(monthCashFlowProvider.future);
    expect(income, 100000);
    expect(expense, 25000);

    // Enriched transaction rows.
    final rows = await container.read(transactionsProvider.future);
    expect(rows, hasLength(3));

    final incomeRow = rows.firstWhere((r) => r.type == TxType.income);
    expect(incomeRow.signedAmountCents, 100000);
    expect(incomeRow.accountName, 'Cash');
    expect(incomeRow.categoryName, 'Salary');

    final expenseRow = rows.firstWhere((r) => r.type == TxType.expense);
    expect(expenseRow.signedAmountCents, -25000);
    expect(expenseRow.accountName, 'Cash');
    expect(expenseRow.categoryName, 'Food');

    final transferRow = rows.firstWhere((r) => r.type == TxType.transfer);
    expect(transferRow.signedAmountCents, -20000);
    expect(transferRow.accountName, 'Cash');
    expect(transferRow.toAccountName, 'Savings');
  });
}
