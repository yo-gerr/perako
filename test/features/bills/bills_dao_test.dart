import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/bills_dao.dart';
import 'package:perako/core/database/daos/database_wipe_service.dart';

void main() {
  late AppDatabase db;
  late BillsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = BillsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  BillsCompanion companion({
    String? id,
    String name = 'Rent',
    int amountCents = 150000,
    String frequency = 'monthly',
    int? dayOfMonth,
    String accountId = 'a1',
    String? categoryId,
    int nextDueDate = 100,
  }) {
    return BillsCompanion(
      id: Value(id ?? 'bil_$name'),
      name: Value(name),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      amountCents: Value(amountCents),
      frequency: Value(frequency),
      dayOfMonth: Value(dayOfMonth),
      nextDueDate: Value(nextDueDate),
      createdAt: const Value(1),
      updatedAt: const Value(1),
      version: const Value(1),
    );
  }

  test('insert returns a row visible to active()', () async {
    final row = await dao.insert(companion(name: 'Internet'));
    expect(row.name, 'Internet');
    expect(await dao.active(), hasLength(1));
    expect(await dao.watchActive().first, hasLength(1));
    expect(await dao.allIncludingArchived(), hasLength(1));
  });

  test('updateBill modifies fields in place', () async {
    final row = await dao.insert(companion());
    await dao.updateBill(BillsCompanion(
      id: Value(row.id),
      name: const Value('Rent + utilities'),
      amountCents: const Value(200000),
      frequency: const Value('monthly'),
      dayOfMonth: const Value(1),
      accountId: const Value('a2'),
      categoryId: const Value(null),
      nextDueDate: const Value(500),
      updatedAt: const Value(2),
    ));

    final updated = await dao.byId(row.id);
    expect(updated!.name, 'Rent + utilities');
    expect(updated.amountCents, 200000);
    expect(updated.accountId, 'a2');
    expect(updated.nextDueDate, 500);
  });

  test('archive hides the row from active and reopen restores it', () async {
    final row = await dao.insert(companion());
    await dao.archive(row.id, nowMillis: 10);

    expect(await dao.active(), isEmpty);
    final archived = await dao.watchArchived().first;
    expect(archived, hasLength(1));
    expect(archived.single.deletedAt, 10);

    await dao.reopen(row.id, nowMillis: 11);
    expect(await dao.active(), hasLength(1));
    expect(await dao.watchArchived().first, isEmpty);
  });

  test('dueBefore returns active bills due at or before the cutoff', () async {
    await dao.insert(companion(name: 'A', nextDueDate: 50));
    await dao.insert(companion(name: 'B', nextDueDate: 150));
    final archived = await dao.insert(
      companion(name: 'C', nextDueDate: 40),
    );
    await dao.archive(archived.id, nowMillis: 60);

    final due = await dao.dueBefore(100);
    expect(due.map((b) => b.name), ['A']);
  });

  test('payment rows are inserted and listed newest-first via watch', () async {
    final row = await dao.insert(companion());
    await dao.insertPayment(BillPaymentsCompanion(
      id: const Value('p1'),
      billId: Value(row.id),
      transactionId: const Value('t1'),
      amountCents: const Value(150000),
      paidOn: const Value(100),
      note: const Value(null),
      createdAt: const Value(1),
    ));
    await dao.insertPayment(BillPaymentsCompanion(
      id: const Value('p2'),
      billId: Value(row.id),
      transactionId: const Value('t2'),
      amountCents: const Value(150000),
      paidOn: const Value(200),
      note: const Value(null),
      createdAt: const Value(2),
    ));

    expect(await dao.paymentsFor(row.id), hasLength(2));
    expect(await dao.latestPaymentFor(row.id), isNotNull);
    expect((await dao.latestPaymentFor(row.id))?.paidOn, 200);
  });

  test('wipeAll removes bills and their payments', () async {
    final row = await dao.insert(companion());
    await dao.insertPayment(BillPaymentsCompanion(
      id: const Value('p1'),
      billId: Value(row.id),
      transactionId: const Value('t1'),
      amountCents: const Value(150000),
      paidOn: const Value(100),
      note: const Value(null),
      createdAt: const Value(1),
    ));

    await DatabaseWipeService(db).wipeAll();
    expect(await db.select(db.bills).get(), isEmpty);
    expect(await db.select(db.billPayments).get(), isEmpty);
  });
}
