import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/bills_dao.dart';
import 'package:perako/features/bills/domain/bill_service.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';

void main() {
  late AppDatabase db;
  late BillsDao billsDao;
  late LedgerEngine engine;
  late BillService service;
  late int clock;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    billsDao = BillsDao(db);
    engine = LedgerEngine(db: db, idGenerator: nextId, clock: () => clock);
    service = BillService(
      db: db,
      engine: engine,
      billsDao: billsDao,
    );
  });

  tearDown(() async {
    await db.close();
    idCounter = 0;
  });

  Future<Bill> insertBill({
    String name = 'Rent',
    int amountCents = 150000,
    String frequency = 'monthly',
    int? dayOfMonth,
    int nextDueDate = 100,
  }) {
    return billsDao.insert(BillsCompanion(
      id: Value(nextId()),
      name: Value(name),
      accountId: const Value('a1'),
      categoryId: const Value(null),
      amountCents: Value(amountCents),
      frequency: Value(frequency),
      dayOfMonth: Value(dayOfMonth),
      nextDueDate: Value(nextDueDate),
      createdAt: const Value(1),
      updatedAt: const Value(1),
      version: const Value(1),
    ));
  }

  group('nextDueAfter', () {
    test('weekly advances by seven days', () async {
      final bill = await insertBill(frequency: 'weekly');
      final next = service.nextDueAfter(bill,
          after: DateTime(2026, 3, 15, 12));
      expect(next, DateTime(2026, 3, 22, 12));
    });

    test('monthly advances a month keeping the anchored day', () async {
      final bill = await insertBill(dayOfMonth: 15);
      final next = service.nextDueAfter(bill,
          after: DateTime(2026, 3, 15, 12));
      expect(next, DateTime(2026, 4, 15, 12));
    });

    test('monthly clamps the 31st to shorter months', () async {
      final bill = await insertBill(dayOfMonth: 31);
      final feb = service.nextDueAfter(bill,
          after: DateTime(2026, 1, 31, 12));
      expect(feb, DateTime(2026, 2, 28, 12));
      // From the clamped date it recovers to the 31st.
      final mar = service.nextDueAfter(bill, after: feb);
      expect(mar, DateTime(2026, 3, 31, 12));
    });

    test('yearly advances a year keeping month and day', () async {
      final bill = await insertBill(frequency: 'yearly', dayOfMonth: 20);
      final next = service.nextDueAfter(bill,
          after: DateTime(2026, 6, 20, 12));
      expect(next, DateTime(2027, 6, 20, 12));
    });
  });

  group('initialDueDate', () {
    test('monthly picks the next occurrence at or after today', () {
      final from = DateTime(2026, 3, 10, 12);
      expect(service.initialDueDate(BillFrequency.monthly, 15, from: from),
          DateTime(2026, 3, 15));
      expect(service.initialDueDate(BillFrequency.monthly, 5, from: from),
          DateTime(2026, 4, 5));
    });

    test('yearly rolls to next year when the day has passed', () {
      final from = DateTime(2026, 3, 10, 12);
      expect(service.initialDueDate(BillFrequency.yearly, 5, from: from),
          DateTime(2027, 3, 5));
    });

    test('weekly is one week out', () {
      final from = DateTime(2026, 3, 10, 12);
      expect(service.initialDueDate(BillFrequency.weekly, null, from: from),
          DateTime(2026, 3, 17, 12));
    });
  });

  group('payBill', () {
    test('posts a balanced expense and records the payment', () async {
      final bill = await insertBill(dayOfMonth: 15);
      final txId = await service.payBill(
        bill,
        on: DateTime(2026, 3, 15, 12),
      );

      // The account was credited the full amount.
      expect(await engine.getBalance('a1'), -150000);

      // Payment history links the posting.
      final payments = await billsDao.paymentsFor(bill.id);
      expect(payments, hasLength(1));
      expect(payments.single.transactionId, txId);
      expect(payments.single.amountCents, 150000);

      // The schedule advanced to next month.
      final updated = await billsDao.byId(bill.id);
      expect(updated!.nextDueDate,
          DateTime(2026, 4, 15, 12).millisecondsSinceEpoch);
    });

    test('paying twice posts two expenses and advances twice', () async {
      final bill = await insertBill(dayOfMonth: 15);
      await service.payBill(bill, on: DateTime(2026, 3, 15, 12));
      await service.payBill(bill, on: DateTime(2026, 4, 15, 12));

      expect(await engine.getBalance('a1'), -300000);
      expect(await billsDao.paymentsFor(bill.id), hasLength(2));
      expect(await billsDao.byId(bill.id).then((b) => b!.nextDueDate),
          DateTime(2026, 5, 15, 12).millisecondsSinceEpoch);
    });
  });

  group('catchUpDueBills', () {
    test('materializes past-due bills once each, idempotently', () async {
      final due = await insertBill(
        name: 'Overdue',
        dayOfMonth: 5,
        nextDueDate: DateTime(2026, 3, 5).millisecondsSinceEpoch,
      );
      final upcoming = await insertBill(
        name: 'Future',
        dayOfMonth: 20,
        nextDueDate: DateTime(2026, 3, 20).millisecondsSinceEpoch,
      );

      final cutoff = DateTime(2026, 3, 15, 12);
      final posted = await service.catchUpDueBills(now: cutoff);
      expect(posted, 1);
      expect(await engine.getBalance('a1'), -150000);

      // The overdue bill advanced to April; the future one is untouched.
      final updatedDue = await billsDao.byId(due.id);
      expect(updatedDue!.nextDueDate,
          DateTime(2026, 4, 5).millisecondsSinceEpoch);
      final untouched = await billsDao.byId(upcoming.id);
      expect(untouched!.nextDueDate,
          DateTime(2026, 3, 20).millisecondsSinceEpoch);

      // Re-running posts nothing new.
      final again = await service.catchUpDueBills(now: cutoff);
      expect(again, 0);
      expect(await engine.getBalance('a1'), -150000);
      expect(await billsDao.paymentsFor(due.id), hasLength(1));
    });

    test('transaction is dated on the original due date', () async {
      await insertBill(
        dayOfMonth: 5,
        nextDueDate: DateTime(2026, 3, 5).millisecondsSinceEpoch,
      );
      await service.catchUpDueBills(now: DateTime(2026, 3, 15));

      final entries = await db.select(db.ledgerEntries).get();
      expect(entries, hasLength(2));
      expect(entries.first.entryDate,
          DateTime(2026, 3, 5).millisecondsSinceEpoch);
    });
  });
}
