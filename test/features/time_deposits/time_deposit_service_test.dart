import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/core/database/daos/time_deposits_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/time_deposits/domain/time_deposit_service.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late TimeDepositsDao dao;
  late TimeDepositService service;
  late int clock;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    idCounter = 0;
    engine = LedgerEngine(
      db: db,
      idGenerator: nextId,
      clock: () => clock,
    );
    dao = TimeDepositsDao(db);
    service = TimeDepositService(
      db: db,
      engine: engine,
      dao: dao,
      idGenerator: nextId,
      clock: () => clock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addAccount(String id) => db.into(db.accounts).insert(
        AccountsCompanion(
          id: Value(id),
          name: Value('Account $id'),
          type: const Value('savings'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(clock),
          updatedAt: Value(clock),
          version: const Value(1),
        ),
      );

  Future<TimeDeposit> createDeposit({
    String accountId = 'a1',
    int principalCents = 100000,
    double rate = 0.06,
    InterestMethod method = InterestMethod.simple,
    DateTime? start,
    DateTime? maturity,
  }) =>
      service.create(
        accountId: accountId,
        label: '1-yr TD',
        principalCents: principalCents,
        annualRate: rate,
        method: method,
        start: start ?? DateTime(2026, 1, 1),
        maturity: maturity ?? DateTime(2027, 1, 1),
      );

  group('maturity value', () {
    test('simple interest over a full year', () {
      expect(
        TimeDepositService.maturityValue(
          principalCents: 100000,
          annualRate: 0.06,
          days: 365,
          method: InterestMethod.simple,
        ),
        106000,
      );
    });

    test('simple interest over a 90-day term', () {
      expect(
        TimeDepositService.maturityValue(
          principalCents: 50000,
          annualRate: 0.05,
          days: 90,
          method: InterestMethod.simple,
        ),
        50616,
      );
    });

    test('compound interest exceeds simple interest', () {
      final simple = TimeDepositService.maturityValue(
        principalCents: 100000,
        annualRate: 0.06,
        days: 365,
        method: InterestMethod.simple,
      );
      final compound = TimeDepositService.maturityValue(
        principalCents: 100000,
        annualRate: 0.06,
        days: 365,
        method: InterestMethod.compound,
      );
      expect(compound, greaterThan(simple));
    });

    test('zero rate or non-positive principal returns the principal', () {
      expect(
        TimeDepositService.maturityValue(
          principalCents: 100000,
          annualRate: 0,
          days: 365,
          method: InterestMethod.simple,
        ),
        100000,
      );
      expect(
        TimeDepositService.maturityValue(
          principalCents: 0,
          annualRate: 0.06,
          days: 365,
          method: InterestMethod.compound,
        ),
        0,
      );
    });
  });

  group('daysBetween', () {
    test('counts whole calendar days', () {
      expect(
        TimeDepositService.daysBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)),
        365,
      );
      expect(
        TimeDepositService.daysBetween(
            DateTime(2026, 1, 1), DateTime(2026, 4, 1)),
        90,
      );
    });
  });

  group('create', () {
    test('stores the projected maturity value', () async {
      await addAccount('a1');
      final deposit = await createDeposit(rate: 0.06);

      expect(deposit.principalCents, 100000);
      expect(deposit.maturityValueCents, 106000);
      expect(deposit.isMatured, isFalse);
      expect(deposit.interestMethod, 'simple');
    });

    test('does not move the principal through the ledger', () async {
      await addAccount('a1');
      await createDeposit();
      expect(await engine.getBalance('a1'), 0);
    });
  });

  group('update', () {
    test('recomputes the maturity value', () async {
      await addAccount('a1');
      final deposit = await createDeposit(rate: 0.06);
      await service.update(
        deposit,
        label: 'Renamed TD',
        principalCents: 200000,
        annualRate: 0.06,
        method: InterestMethod.simple,
        start: DateTime(2026, 1, 1),
        maturity: DateTime(2027, 1, 1),
      );

      final reloaded = await dao.byId(deposit.id);
      expect(reloaded!.label, 'Renamed TD');
      expect(reloaded.principalCents, 200000);
      expect(reloaded.maturityValueCents, 212000);
    });
  });

  group('processMaturities', () {
    test('posts the interest as income on the maturity date', () async {
      await addAccount('a1');
      final deposit = await createDeposit(rate: 0.06);
      // Deposit balance comes from an earlier income.
      await engine.postTransaction(
        description: 'opening',
        on: DateTime(2026, 1, 2),
        lines: [
          LedgerLine(
              accountId: 'a1',
              type: EntryType.debit,
              amountCents: deposit.principalCents),
          LedgerLine(
              accountId: 'income',
              type: EntryType.credit,
              amountCents: deposit.principalCents),
        ],
      );

      final processed = await service.processMaturities(
          now: DateTime(2027, 1, 2, 12));

      expect(processed, 1);
      final reloaded = await dao.byId(deposit.id);
      expect(reloaded!.isMatured, isTrue);
      expect(reloaded.maturedTransactionId, isNotNull);
      expect(await engine.getBalance('a1'), 106000);
      // The interest posting is dated on the maturity date.
      final entries = await LedgerDao(db).entriesForAccount('a1');
      final incomeEntry = entries
          .where((e) => e.entryDate == DateTime(2027, 1, 1).millisecondsSinceEpoch)
          .toList();
      expect(incomeEntry, hasLength(1));
      expect(incomeEntry.first.amount, 6000);
    });

    test('is idempotent and processes nothing twice', () async {
      await addAccount('a1');
      await createDeposit(rate: 0.06);
      await service.processMaturities(now: DateTime(2027, 1, 2));
      final again = await service.processMaturities(now: DateTime(2027, 1, 2));
      expect(again, 0);
    });

    test('marks a zero-interest deposit matured without a posting', () async {
      await addAccount('a1');
      final deposit = await createDeposit(rate: 0);

      final processed = await service.processMaturities(
          now: DateTime(2027, 1, 2));

      expect(processed, 1);
      final reloaded = await dao.byId(deposit.id);
      expect(reloaded!.isMatured, isTrue);
      expect(reloaded.maturedTransactionId, isNull);
      expect(await engine.getBalance('a1'), 0);
    });

    test('leaves unmatured deposits alone', () async {
      await addAccount('a1');
      await createDeposit(maturity: DateTime(2027, 6, 1));

      final processed =
          await service.processMaturities(now: DateTime(2027, 1, 2));

      expect(processed, 0);
      final reloaded = await dao.byId('id_0');
      expect(reloaded!.isMatured, isFalse);
    });
  });

  group('dao', () {
    test('archive hides a deposit, reopen restores it', () async {
      await addAccount('a1');
      final deposit = await createDeposit();

      await dao.archive(deposit.id, nowMillis: clock + 1);
      expect(await dao.active(), isEmpty);
      expect(await dao.archived(), hasLength(1));

      await dao.reopen(deposit.id, nowMillis: clock + 2);
      expect(await dao.active(), hasLength(1));
      expect(await dao.archived(), isEmpty);
    });

    test('dueToMature returns only unmatured, undelleted, past-due deposits',
        () async {
      await addAccount('a1');
      final due = await createDeposit(
          maturity: DateTime(2027, 1, 1), principalCents: 1);
      await createDeposit(maturity: DateTime(2027, 6, 1), principalCents: 2);
      await createDeposit(
          maturity: DateTime(2027, 12, 1),
          principalCents: 3,
          start: DateTime(2026, 12, 1));

      final found =
          await dao.dueToMature(DateTime(2027, 2, 1).millisecondsSinceEpoch);
      expect(found.map((d) => d.id), [due.id]);
    });
  });
}
