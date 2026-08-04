import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/categories_dao.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';
import 'package:perako/features/transactions/presentation/screens/transaction_form_screen.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = LedgerEngine(db: db);

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

  Future<String> postIncome() {
    return engine.postTransaction(
      description: 'January salary',
      notes: 'January salary',
      on: DateTime.utc(2026, 1, 15),
      lines: buildLedgerLines(
        type: TxType.income,
        accountId: 'acc_cash',
        categoryId: 'cat_salary',
        amountCents: 10000,
      ),
    );
  }

  Future<void> pumpEditForm(WidgetTester tester, String id) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: '/transactions/:id/edit',
          builder: (context, state) => TransactionFormScreen(
              transactionId: state.pathParameters['id']),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/transactions/$id/edit');
    await tester.pumpAndSettle();
  }

  testWidgets('edit form prefills the existing transaction', (tester) async {
    final id = await postIncome();
    await pumpEditForm(tester, id);

    expect(find.widgetWithText(AppBar, 'Edit transaction'), findsOneWidget);
    // Prefilled amount from the posted 100.00 income.
    expect(find.widgetWithText(TextField, '100.00'), findsOneWidget);
    // Account dropdown shows the source account.
    expect(find.text('Cash'), findsOneWidget);
    // Income category was preserved, proving the type loaded as income.
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Savings'), findsNothing);
  });

  testWidgets('saving an edit reverses the original and posts the correction',
      (tester) async {
    final id = await postIncome();
    await pumpEditForm(tester, id);

    await tester.enterText(
        find.widgetWithText(TextField, '100.00'), '50.00');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Back on the parent route after a successful save.
    expect(find.text('home'), findsOneWidget);

    // Net effect on the account: +100.00 original, -100.00 reversal,
    // +50.00 corrected = +50.00.
    expect(await engine.getBalance('acc_cash'), 5000);
  });
}
