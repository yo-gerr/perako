import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/budgets_dao.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/features/budgets/domain/budget_service.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';

void main() {
  late AppDatabase db;
  late LedgerDao ledgerDao;
  late BudgetsDao budgetsDao;
  late LedgerEngine engine;
  late BudgetService service;
  late int clock;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  final now = DateTime(2026, 3, 15, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    ledgerDao = LedgerDao(db);
    budgetsDao = BudgetsDao(db);
    engine = LedgerEngine(db: db, idGenerator: nextId, clock: () => clock);
    service = BudgetService(ledgerDao: ledgerDao);
  });

  tearDown(() async {
    await db.close();
    idCounter = 0;
  });

  Future<void> postExpense({
    required String accountId,
    required String categoryId,
    required int amountCents,
    required DateTime on,
  }) async {
    await engine.postTransaction(
      description: 'expense',
      on: on,
      lines: buildLedgerLines(
        type: TxType.expense,
        accountId: accountId,
        categoryId: categoryId,
        amountCents: amountCents,
      ),
    );
  }

  BudgetsCompanion budget({
    required int amountCents,
    String? categoryId,
    String? accountId,
    bool rollover = false,
    int createdAt = 0,
  }) {
    return BudgetsCompanion(
      id: Value(nextId()),
      name: const Value('Groceries'),
      amountCents: Value(amountCents),
      period: const Value('monthly'),
      categoryId: Value(categoryId),
      accountId: Value(accountId),
      rollover: Value(rollover),
      createdAt: Value(createdAt),
      updatedAt: Value(createdAt),
      version: const Value(1),
    );
  }

  group('windowFor', () {
    Future<Budget> insertWindow({
      required String period,
      int? startDate,
      int? endDate,
    }) {
      return budgetsDao.insert(BudgetsCompanion(
        id: Value(nextId()),
        name: const Value('x'),
        amountCents: const Value(10000),
        period: Value(period),
        categoryId: const Value(null),
        accountId: const Value(null),
        rollover: const Value(false),
        startDate: Value(startDate),
        endDate: Value(endDate),
        createdAt: const Value(0),
        updatedAt: const Value(0),
      ));
    }

    test('monthly window is the whole calendar month', () async {
      final b = await insertWindow(period: 'monthly');
      final w = service.windowFor(b, now);
      expect(w.start, DateTime(2026, 3, 1));
      expect(w.end,
          DateTime(2026, 4, 1).subtract(const Duration(milliseconds: 1)));
    });

    test('yearly window spans Jan 1 to Dec 31', () async {
      final b = await insertWindow(period: 'yearly');
      final w = service.windowFor(b, now);
      expect(w.start, DateTime(2026, 1, 1));
      expect(w.end,
          DateTime(2027, 1, 1).subtract(const Duration(milliseconds: 1)));
    });

    test('clamps to explicit startDate/endDate bounds', () async {
      final b = await insertWindow(
        period: 'monthly',
        startDate: DateTime(2026, 3, 10).millisecondsSinceEpoch,
        endDate: DateTime(2026, 3, 20).millisecondsSinceEpoch,
      );
      final w = service.windowFor(b, now);
      expect(w.start, DateTime(2026, 3, 10));
      expect(w.end, DateTime(2026, 3, 20));
    });
  });

  group('progress', () {
    test('measures spent and derives forecast and amount-per-day', () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 50000, categoryId: 'food', createdAt: 1),
      );

      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 10000,
        on: DateTime(2026, 3, 10),
      );

      final p = await service.progress(b, now: now);
      expect(p.spentCents, 10000);
      expect(p.amountCents, 50000);
      expect(p.remainingCents, 40000);
      expect(p.isOver, false);
      expect(p.amountPerDayCents, 2352);
      expect(p.forecastCents, 21333);
      expect(p.periodLabel, 'Mar 2026');
    });

    test('isOver when spending exceeds the budget', () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 5000, categoryId: 'food', createdAt: 1),
      );
      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 6000,
        on: DateTime(2026, 3, 5),
      );

      final p = await service.progress(b, now: now);
      expect(p.isOver, true);
      expect(p.remainingCents, -1000);
      expect(p.ratio, greaterThan(1));
    });

    test('account-scoped budget ignores other accounts and transfers',
        () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 50000, accountId: 'a1', createdAt: 1),
      );

      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 3000,
        on: DateTime(2026, 3, 5),
      );
      await postExpense(
        accountId: 'a2',
        categoryId: 'food',
        amountCents: 2000,
        on: DateTime(2026, 3, 6),
      );
      // Transfer in/out of a1 — must not count as spending.
      await engine.postTransaction(
        description: 'move',
        on: DateTime(2026, 3, 7),
        lines: [
          LedgerLine(
              accountId: 'a2', type: EntryType.debit, amountCents: 5000),
          LedgerLine(
              accountId: 'a1', type: EntryType.credit, amountCents: 5000),
        ],
      );

      final p = await service.progress(b, now: now);
      expect(p.spentCents, 3000);
    });
  });

  group('effectiveAmount / rollover', () {
    test('carries a positive remainder into the next period', () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 50000, categoryId: 'food', rollover: true,
            createdAt: DateTime(2026, 2, 1).millisecondsSinceEpoch),
      );
      // Spent only 30k of the February 50k budget.
      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 30000,
        on: DateTime(2026, 2, 10),
      );

      final amount = await service.effectiveAmount(b, now);
      expect(amount, 70000);
    });

    test('does not carry a deficit forward', () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 50000, categoryId: 'food', rollover: true,
            createdAt: DateTime(2026, 2, 1).millisecondsSinceEpoch),
      );
      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 60000,
        on: DateTime(2026, 2, 10),
      );

      final amount = await service.effectiveAmount(b, now);
      expect(amount, 50000);
    });

    test('does not carry from before the budget was created', () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 50000, categoryId: 'food', rollover: true,
            createdAt: DateTime(2026, 3, 10).millisecondsSinceEpoch),
      );
      // Spending in February, before the budget existed.
      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 10000,
        on: DateTime(2026, 2, 10),
      );

      final amount = await service.effectiveAmount(b, now);
      expect(amount, 50000);
    });
  });

  group('spentForCategory', () {
    test('sums spending for the limit category within the period', () async {
      final b = await budgetsDao.insert(
        budget(amountCents: 50000, createdAt: 1),
      );
      await postExpense(
        accountId: 'a1',
        categoryId: 'food',
        amountCents: 12000,
        on: DateTime(2026, 3, 2),
      );
      await postExpense(
        accountId: 'a1',
        categoryId: 'other',
        amountCents: 9000,
        on: DateTime(2026, 3, 3),
      );

      final window = service.windowFor(b, now);
      expect(await service.spentForCategory('food', window), 12000);
      expect(await service.spentForCategory('other', window), 9000);
    });
  });
}

