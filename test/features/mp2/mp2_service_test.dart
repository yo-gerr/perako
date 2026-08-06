import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/core/database/daos/mp2_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/mp2/domain/mp2_service.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late Mp2Dao dao;
  late Mp2Service service;
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
    dao = Mp2Dao(db);
    service = Mp2Service(
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

  Future<Mp2Account> createMp2({
    String accountId = 'a1',
    double rate = 0.07,
    DateTime? start,
  }) =>
      service.create(
        accountId: accountId,
        label: 'My MP2',
        dividendRate: rate,
        startDate: start ?? DateTime(2026, 1, 1),
      );

  /// Seeds an MP2 account with a ledger balance via a contribution.
  Future<Mp2Account> seededMp2({
    int amountCents = 100000,
    double rate = 0.07,
    DateTime? start,
    DateTime? on,
  }) async {
    await addAccount('a1');
    await addAccount('cash');
    final mp2 = await createMp2(rate: rate, start: start);
    await service.contribute(
      mp2,
      sourceAccountId: 'cash',
      amountCents: amountCents,
      on: on ?? DateTime(2026, 1, 2),
    );
    return mp2;
  }

  group('term math', () {
    test('maturityDateFor is five years after the start', () {
      expect(
        Mp2Service.maturityDateFor(DateTime(2026, 1, 1)),
        DateTime(2031, 1, 1),
      );
      expect(
        Mp2Service.maturityDateFor(DateTime(2024, 6, 15)),
        DateTime(2029, 6, 15),
      );
    });

    test('annualDividend averages the year\'s contributions in', () {
      expect(
        Mp2Service.annualDividend(
          openingBalanceCents: 100000,
          contributionsInYearCents: 20000,
          dividendRate: 0.07,
        ),
        7700,
      );
      expect(
        Mp2Service.annualDividend(
          openingBalanceCents: 33333,
          contributionsInYearCents: 0,
          dividendRate: 0.07,
        ),
        2333,
      );
      expect(
        Mp2Service.annualDividend(
          openingBalanceCents: 100000,
          contributionsInYearCents: 0,
          dividendRate: 0,
        ),
        0,
      );
    });
  });

  group('create and update', () {
    test('create stores a five-year term without moving money', () async {
      await addAccount('a1');
      final mp2 = await createMp2();

      expect(mp2.maturityDate,
          DateTime(2031, 1, 1).millisecondsSinceEpoch);
      expect(mp2.isMatured, isFalse);
      expect(await engine.getBalance('a1'), 0);
    });

    test('update re-derives the maturity date from the new start', () async {
      await addAccount('a1');
      final mp2 = await createMp2();
      await service.update(
        mp2,
        label: 'Renamed MP2',
        dividendRate: 0.05,
        startDate: DateTime(2027, 3, 1),
      );

      final reloaded = await dao.byId(mp2.id);
      expect(reloaded!.label, 'Renamed MP2');
      expect(reloaded.dividendRate, 0.05);
      expect(reloaded.maturityDate,
          DateTime(2032, 3, 1).millisecondsSinceEpoch);
    });
  });

  group('contribute and withdraw', () {
    test('contribute posts a balanced transfer and records a contribution',
        () async {
      await addAccount('a1');
      await addAccount('cash');
      final mp2 = await createMp2();

      final txId = await service.contribute(
        mp2,
        sourceAccountId: 'cash',
        amountCents: 100000,
        on: DateTime(2026, 1, 15),
        note: 'first',
      );

      expect(await engine.getBalance('a1'), 100000);
      expect(await engine.getBalance('cash'), -100000);
      final rows = await dao.contributionsFor(mp2.id);
      expect(rows, hasLength(1));
      expect(rows.first.amountCents, 100000);
      expect(rows.first.transactionId, txId);
      expect(rows.first.note, 'first');
      expect(rows.first.contributedOn,
          DateTime(2026, 1, 15).millisecondsSinceEpoch);
    });

    test('withdraw posts a balanced transfer out', () async {
      await addAccount('a1');
      await addAccount('cash');
      final mp2 = await createMp2();
      await service.contribute(
        mp2,
        sourceAccountId: 'cash',
        amountCents: 100000,
      );

      await service.withdraw(
        mp2,
        toAccountId: 'cash',
        amountCents: 40000,
        on: DateTime(2026, 7, 1),
      );

      expect(await engine.getBalance('a1'), 60000);
      expect(await engine.getBalance('cash'), -60000);
      final rows = await dao.withdrawalsFor(mp2.id);
      expect(rows, hasLength(1));
      expect(rows.first.amountCents, 40000);
    });
  });

  group('processDividends', () {
    test('realizes each passed year on its anniversary and never twice',
        () async {
      final mp2 = await seededMp2();

      final processed = await service.processDividends(
          now: DateTime(2028, 1, 2, 12));

      expect(processed, 2);
      final dividends = await dao.dividendsFor(mp2.id);
      expect(dividends.map((d) => d.year).toSet(), {0, 1});
      expect(dividends.map((d) => d.amountCents), [3500, 7245]);
      expect(await engine.getBalance('a1'), 110745);

      // Year 0: (0 + 100000/2) * 0.07; Year 1: 103500 * 0.07.
      final entries = await LedgerDao(db).entriesForAccount('a1');
      expect(
        entries
            .where((e) =>
                e.entryDate == DateTime(2027, 1, 1).millisecondsSinceEpoch)
            .map((e) => e.amount),
        [3500],
      );

      final again = await service.processDividends(now: DateTime(2028, 1, 2));
      expect(again, 0);
    });

    test('never credits years beyond the five-year term', () async {
      final mp2 = await seededMp2();

      final processed = await service.processDividends(
          now: DateTime(2032, 1, 2));

      expect(processed, 5);
      final dividends = await dao.dividendsFor(mp2.id);
      expect(dividends.map((d) => d.year).toSet(), {0, 1, 2, 3, 4});
      expect(await engine.getBalance('a1'), 135667);
    });

    test('records a zero dividend without posting a transaction', () async {
      await addAccount('a1');
      final mp2 = await createMp2();

      final processed =
          await service.processDividends(now: DateTime(2027, 1, 2));

      expect(processed, 1);
      final rows = await dao.dividendsFor(mp2.id);
      expect(rows, hasLength(1));
      expect(rows.first.amountCents, 0);
      expect(rows.first.transactionId, isNull);
      expect(await engine.getBalance('a1'), 0);
    });
  });

  group('processMaturities', () {
    test('marks an account matured once the term ends', () async {
      await addAccount('a1');
      final mp2 = await createMp2(start: DateTime(2026, 1, 1));

      expect(await service.processMaturities(now: DateTime(2030, 12, 31)), 0);
      expect((await dao.byId(mp2.id))!.isMatured, isFalse);

      expect(await service.processMaturities(now: DateTime(2031, 1, 2)), 1);
      expect((await dao.byId(mp2.id))!.isMatured, isTrue);

      expect(await service.processMaturities(now: DateTime(2031, 1, 2)), 0);
    });
  });

  group('forecasting', () {
    test('forecastAnnualDividends compounds the current balance forward',
        () async {
      final mp2 = await seededMp2();

      final forecast = await service.forecastAnnualDividends(
        mp2,
        now: DateTime(2027, 6, 15),
      );

      expect(forecast, hasLength(5));
      expect(forecast.first.yearNumber, 1);
      expect(forecast.first.anniversary, DateTime(2027, 1, 1));
      expect(forecast.first.dividendCents, 7000);
      expect(forecast.first.balanceAfterCents, 107000);
      expect(forecast.last.yearNumber, 5);
      expect(forecast.last.balanceAfterCents, 140255);
    });

    test('forecastMaturityValue grows the balance through every remaining year',
        () async {
      final mp2 = await seededMp2();

      final maturity = await service.forecastMaturityValue(
        mp2,
        now: DateTime(2026, 6, 1),
      );

      expect(maturity, 140255);
      expect(maturity, greaterThan(await engine.getBalance('a1')));
    });

    test('a fully-realized account forecasts nothing', () async {
      final mp2 = await seededMp2();
      await service.processDividends(now: DateTime(2032, 1, 2));

      final forecast =
          await service.forecastAnnualDividends(mp2, now: DateTime(2032, 1, 2));

      expect(forecast, isEmpty);
      expect(
        await service.forecastMaturityValue(mp2),
        await engine.getBalance('a1'),
      );
    });
  });

  group('dao', () {
    test('archive hides an account, reopen restores it', () async {
      await addAccount('a1');
      final mp2 = await createMp2();

      await dao.archive(mp2.id, nowMillis: clock + 1);
      expect(await dao.active(), isEmpty);
      expect(await dao.archived(), hasLength(1));

      await dao.reopen(mp2.id, nowMillis: clock + 2);
      expect(await dao.active(), hasLength(1));
      expect(await dao.archived(), isEmpty);
    });

    test('contributionsBetween uses a half-open window', () async {
      await addAccount('a1');
      await addAccount('cash');
      final mp2 = await createMp2();
      await service.contribute(
          mp2, sourceAccountId: 'cash', amountCents: 10000,
          on: DateTime(2026, 1, 15));
      await service.contribute(
          mp2, sourceAccountId: 'cash', amountCents: 20000,
          on: DateTime(2026, 6, 1));

      final rows = await dao.contributionsBetween(
        mp2.id,
        fromMillis: DateTime(2026, 2, 1).millisecondsSinceEpoch,
        toMillis: DateTime(2026, 7, 1).millisecondsSinceEpoch,
      );

      expect(rows.map((c) => c.amountCents), [20000]);
    });
  });
}
