import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/reports/domain/report_service.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late ReportService service;
  late AccountsDao accountsDao;
  late int clock;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    idCounter = 0;
    accountsDao = AccountsDao(db);
    engine = LedgerEngine(
      db: db,
      idGenerator: nextId,
      clock: () => clock,
    );
    service = ReportService(
      ledgerDao: LedgerDao(db),
      accountsDao: accountsDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addAccount(String id) => accountsDao.insertAccount(
        AccountsCompanion(
          id: Value(id),
          name: Value(id),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(clock),
          updatedAt: Value(clock),
          version: const Value(1),
        ),
      );

  group('resolveForRange', () {
    test('picks daily, weekly, or monthly by span', () {
      expect(
        resolveForRange(DateTime(2026, 1, 1), DateTime(2026, 2, 1)),
        ReportResolution.daily,
      );
      expect(
        resolveForRange(DateTime(2026, 1, 1), DateTime(2026, 7, 1)),
        ReportResolution.weekly,
      );
      expect(
        resolveForRange(DateTime(2020, 1, 1), DateTime(2026, 1, 1)),
        ReportResolution.monthly,
      );
    });
  });

  group('bucketEnds', () {
    test('daily covers every calendar day', () {
      final ends = service.bucketEnds(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 3, 12),
        resolution: ReportResolution.daily,
      );
      expect(ends, hasLength(3));
      expect(ends[0].day, 1);
      expect(ends[1].day, 2);
      expect(ends[2].day, 3);
    });

    test('weekly anchors windows to from', () {
      final ends = service.bucketEnds(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
        resolution: ReportResolution.weekly,
      );
      expect(ends, hasLength(5));
      expect(ends[0].day, 7);
      expect(ends[4].day, 4);
      expect(ends[4].month, 2);
    });

    test('monthly closes at each month end', () {
      final ends = service.bucketEnds(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 3, 31),
        resolution: ReportResolution.monthly,
      );
      expect(ends, hasLength(3));
      expect(ends[0].day, 31);
      expect(ends[1].day, 28); // 2026 is not a leap year.
      expect(ends[2].day, 31);
    });
  });

  group('netWorthSeries', () {
    test('carries balances as-of each bucket end across the whole range',
        () async {
      await addAccount('checking');
      await addAccount('savings');

      await engine.postTransaction(
        description: 'salary',
        on: DateTime(2026, 1, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 100000),
          LedgerLine(
              accountId: 'counterparty_income',
              type: EntryType.credit,
              amountCents: 100000),
        ],
      );
      await engine.postTransaction(
        description: 'transfer to savings',
        on: DateTime(2026, 1, 10, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.credit, amountCents: 40000),
          LedgerLine(
              accountId: 'savings', type: EntryType.debit, amountCents: 40000),
        ],
      );
      await engine.postTransaction(
        description: 'groceries',
        on: DateTime(2026, 1, 20, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.credit, amountCents: 15000),
          LedgerLine(
              accountId: 'counterparty_expense',
              type: EntryType.debit,
              amountCents: 15000),
        ],
      );

      final points = await service.netWorthSeries(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31, 12),
        resolution: ReportResolution.daily,
      );
      expect(points, hasLength(31));
      expect(points[0].cents, 0); // Before any activity.
      expect(points[4].cents, 100000); // Jan 5 salary lands.
      expect(points[9].cents, 100000); // Transfer conserves value.
      expect(points[19].cents, 85000); // Jan 20 expense.
      expect(points[30].cents, 85000); // Unchanged at month end.
      expect(points[30].date.millisecondsSinceEpoch,
          lessThan(DateTime(2026, 2, 1).millisecondsSinceEpoch));
    });

    test('ignores entries for accounts that no longer exist', () async {
      await addAccount('checking');
      await engine.postTransaction(
        description: 'orphan deposit',
        on: DateTime(2026, 1, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'ghost', type: EntryType.debit, amountCents: 100000),
          LedgerLine(
              accountId: 'counterparty_income',
              type: EntryType.credit,
              amountCents: 100000),
        ],
      );

      final points = await service.netWorthSeries(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31, 12),
        resolution: ReportResolution.daily,
      );
      expect(points.last.cents, 0);
    });
  });

  group('cashFlowSeries', () {
    test('attributes income and expense to their own buckets', () async {
      await engine.postTransaction(
        description: 'salary',
        on: DateTime(2026, 1, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 100000),
          LedgerLine(
              accountId: 'counterparty_income',
              type: EntryType.credit,
              amountCents: 100000),
        ],
      );
      await engine.postTransaction(
        description: 'rent',
        on: DateTime(2026, 1, 20, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.credit, amountCents: 20000),
          LedgerLine(
              accountId: 'counterparty_expense',
              type: EntryType.debit,
              amountCents: 20000),
        ],
      );

      final points = await service.cashFlowSeries(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31, 12),
        resolution: ReportResolution.daily,
      );
      expect(points, hasLength(31));
      expect(points[4].incomeCents, 100000);
      expect(points[4].expenseCents, 0);
      expect(points[19].expenseCents, 20000);
      expect(points[19].incomeCents, 0);

      final totalIncome = points.fold<int>(0, (s, p) => s + p.incomeCents);
      final totalExpense = points.fold<int>(0, (s, p) => s + p.expenseCents);
      expect(totalIncome, 100000);
      expect(totalExpense, 20000);
    });

    test('internal transfers do not count as income or expense', () async {
      await engine.postTransaction(
        description: 'transfer',
        on: DateTime(2026, 1, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.credit, amountCents: 30000),
          LedgerLine(
              accountId: 'savings', type: EntryType.debit, amountCents: 30000),
        ],
      );

      final points = await service.cashFlowSeries(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31, 12),
        resolution: ReportResolution.daily,
      );
      expect(points[4].incomeCents, 0);
      expect(points[4].expenseCents, 0);
    });
  });

  group('expenseByCategory / incomeByCategory', () {
    test('groups by category and surfaces uncategorized as null', () async {
      await engine.postTransaction(
        description: 'salary',
        on: DateTime(2026, 1, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 100000),
          LedgerLine(
              accountId: 'counterparty_income',
              type: EntryType.credit,
              amountCents: 100000,
              categoryId: 'pay'),
        ],
      );
      await engine.postTransaction(
        description: 'groceries',
        on: DateTime(2026, 1, 10, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.credit, amountCents: 15000),
          LedgerLine(
              accountId: 'counterparty_expense',
              type: EntryType.debit,
              amountCents: 15000,
              categoryId: 'food'),
        ],
      );
      await engine.postTransaction(
        description: 'parking',
        on: DateTime(2026, 1, 12, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.credit, amountCents: 8000),
          LedgerLine(
              accountId: 'counterparty_expense',
              type: EntryType.debit,
              amountCents: 8000),
        ],
      );

      final expenses = await service.expenseByCategory(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      expect(expenses, hasLength(2));
      expect(expenses, contains(CategoryAmount(categoryId: 'food', cents: 15000)));
      expect(expenses, contains(CategoryAmount(categoryId: null, cents: 8000)));

      final income = await service.incomeByCategory(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      expect(income, [CategoryAmount(categoryId: 'pay', cents: 100000)]);
    });

    test('respects the inclusive range bounds', () async {
      await engine.postTransaction(
        description: 'salary jan',
        on: DateTime(2026, 1, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 50000),
          LedgerLine(
              accountId: 'counterparty_income',
              type: EntryType.credit,
              amountCents: 50000,
              categoryId: 'pay'),
        ],
      );
      await engine.postTransaction(
        description: 'salary feb',
        on: DateTime(2026, 2, 5, 12),
        lines: const [
          LedgerLine(
              accountId: 'checking', type: EntryType.debit, amountCents: 60000),
          LedgerLine(
              accountId: 'counterparty_income',
              type: EntryType.credit,
              amountCents: 60000,
              categoryId: 'pay'),
        ],
      );

      final income = await service.incomeByCategory(
        from: DateTime(2026, 2, 1),
        to: DateTime(2026, 2, 28),
      );
      expect(income, [CategoryAmount(categoryId: 'pay', cents: 60000)]);
    });
  });

  group('CSV export', () {
    test('net worth csv has a header and one row per point', () {
      final csv = ReportService.csvForNetWorth([
        NetWorthPoint(date: DateTime(2026, 1, 31), cents: 123456),
      ]);
      expect(csv, 'Date,Net worth (cents)\n2026-1-31,123456');
    });

    test('cash flow csv includes income and expense columns', () {
      final csv = ReportService.csvForCashFlow([
        CashFlowPoint(
          date: DateTime(2026, 1, 31),
          incomeCents: 1000,
          expenseCents: 400,
        ),
      ]);
      expect(
        csv,
        'Date,Income (cents),Expense (cents)\n2026-1-31,1000,400',
      );
    });

    test('escapes commas and quotes in category names', () {
      final csv = ReportService.csvForCategory(
        [CategoryAmount(categoryId: 'x', cents: 500)],
        {'x': 'Food, "Fast"'},
        column: 'Spending',
      );
      expect(
        csv,
        'Category,Spending (cents)\n"Food, ""Fast""",500',
      );
    });
  });
}
