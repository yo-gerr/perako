import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/bonds_dao.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/features/bonds/domain/bond_service.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late BondsDao dao;
  late BondService service;
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
    dao = BondsDao(db);
    service = BondService(
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

  /// Credits [cents] into [accountId] to stand in for the bond principal.
  Future<void> seedBalance(String accountId, int cents) =>
      engine.postTransaction(
        description: 'opening',
        on: DateTime(2026, 1, 1),
        lines: [
          LedgerLine(
              accountId: accountId,
              type: EntryType.debit,
              amountCents: cents),
          LedgerLine(
              accountId: 'income',
              type: EntryType.credit,
              amountCents: cents),
        ],
      );

  Future<Bond> createBond({
    String accountId = 'a1',
    int faceValueCents = 100000,
    double rate = 0.06,
    CouponSchedule schedule = CouponSchedule.annual,
    DateTime? start,
    DateTime? maturity,
  }) =>
      service.create(
        accountId: accountId,
        label: '5-yr RTB',
        faceValueCents: faceValueCents,
        couponRate: rate,
        schedule: schedule,
        startDate: start ?? DateTime(2026, 1, 1),
        maturityDate: maturity ?? DateTime(2031, 1, 1),
      );

  group('coupon math', () {
    test('prorates the annual rate over the schedule interval', () {
      expect(
        BondService.couponAmount(
            faceValueCents: 100000, couponRate: 0.06, schedule: CouponSchedule.annual),
        6000,
      );
      expect(
        BondService.couponAmount(
            faceValueCents: 100000,
            couponRate: 0.06,
            schedule: CouponSchedule.semiAnnual),
        3000,
      );
      expect(
        BondService.couponAmount(
            faceValueCents: 100000,
            couponRate: 0.06,
            schedule: CouponSchedule.quarterly),
        1500,
      );
      expect(
        BondService.couponAmount(
            faceValueCents: 100000,
            couponRate: 0.06,
            schedule: CouponSchedule.monthly),
        500,
      );
      expect(
        BondService.couponAmount(
            faceValueCents: 100000,
            couponRate: 0,
            schedule: CouponSchedule.quarterly),
        0,
      );
    });
  });

  group('coupon dates', () {
    test('anchors dates to the start at the schedule interval', () {
      expect(
        BondService.couponDates(
            DateTime(2026, 1, 1), CouponSchedule.annual, DateTime(2031, 1, 1)),
        [
          DateTime(2027, 1, 1),
          DateTime(2028, 1, 1),
          DateTime(2029, 1, 1),
          DateTime(2030, 1, 1),
          DateTime(2031, 1, 1),
        ],
      );
    });

    test('clamps end-of-month dates without drifting off the start day', () {
      expect(
        BondService.couponDates(
            DateTime(2026, 1, 31), CouponSchedule.monthly, DateTime(2026, 4, 30)),
        [DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)],
      );
    });

    test('firstCouponDateAfter is strictly after the anchor', () {
      expect(
        BondService.firstCouponDateAfter(
            DateTime(2026, 1, 1), CouponSchedule.annual, DateTime(2027, 1, 1)),
        DateTime(2028, 1, 1),
      );
      expect(
        BondService.firstCouponDateAfter(
            DateTime(2026, 1, 1), CouponSchedule.quarterly, DateTime(2026, 1, 15)),
        DateTime(2026, 4, 1),
      );
    });
  });

  group('create and update', () {
    test('create seeds the coupon cursor without moving money', () async {
      await addAccount('a1');
      final bond = await createBond();

      expect(bond.faceValueCents, 100000);
      expect(bond.couponSchedule, 'annual');
      expect(bond.nextCouponDate,
          DateTime(2027, 1, 1).millisecondsSinceEpoch);
      expect(bond.isMatured, isFalse);
      expect(await engine.getBalance('a1'), 0);
    });

    test('update re-seeds the cursor past the last realized coupon', () async {
      await addAccount('a1');
      final bond = await createBond(
        schedule: CouponSchedule.quarterly,
        maturity: DateTime(2027, 12, 31),
      );
      await service.processCoupons(now: DateTime(2026, 10, 2));

      await service.update(
        bond,
        label: 'Renamed bond',
        faceValueCents: 200000,
        couponRate: 0.05,
        schedule: CouponSchedule.quarterly,
        startDate: DateTime(2026, 1, 1),
        maturityDate: DateTime(2027, 12, 31),
      );

      final reloaded = await dao.byId(bond.id);
      expect(reloaded!.label, 'Renamed bond');
      expect(reloaded.faceValueCents, 200000);
      expect(reloaded.nextCouponDate,
          DateTime(2027, 1, 1).millisecondsSinceEpoch);
    });
  });

  group('processCoupons', () {
    test('posts each due coupon as income on its coupon date', () async {
      await addAccount('a1');
      await seedBalance('a1', 100000);
      final bond = await createBond();

      final processed =
          await service.processCoupons(now: DateTime(2028, 1, 2, 12));

      expect(processed, 2);
      expect(await engine.getBalance('a1'), 112000);
      final rows = await dao.couponsFor(bond.id);
      expect(rows.map((c) => c.period), [0, 1]);
      expect(rows.map((c) => c.couponCents), [6000, 6000]);

      final entries = await LedgerDao(db).entriesForAccount('a1');
      final couponEntry = entries
          .where((e) =>
              e.entryDate == DateTime(2027, 1, 1).millisecondsSinceEpoch)
          .toList();
      expect(couponEntry, hasLength(1));
      expect(couponEntry.first.amount, 6000);

      // The cursor advances to the next unpaid coupon date.
      final reloaded = await dao.byId(bond.id);
      expect(reloaded!.nextCouponDate,
          DateTime(2029, 1, 1).millisecondsSinceEpoch);
    });

    test('is idempotent and never credits a coupon twice', () async {
      await addAccount('a1');
      await seedBalance('a1', 100000);
      await createBond();

      await service.processCoupons(now: DateTime(2028, 1, 2));
      final again = await service.processCoupons(now: DateTime(2028, 1, 2));

      expect(again, 0);
    });

    test('never credits coupons past the term', () async {
      await addAccount('a1');
      await seedBalance('a1', 100000);
      final bond = await createBond();

      final processed =
          await service.processCoupons(now: DateTime(2032, 1, 2));

      expect(processed, 5);
      final rows = await dao.couponsFor(bond.id);
      expect(rows.map((c) => c.period), [0, 1, 2, 3, 4]);
      expect(await engine.getBalance('a1'), 130000);
    });

    test('records a zero-rate coupon without posting a transaction', () async {
      await addAccount('a1');
      final bond = await createBond(rate: 0);

      final processed =
          await service.processCoupons(now: DateTime(2028, 1, 2));

      expect(processed, 2);
      final rows = await dao.couponsFor(bond.id);
      expect(rows, hasLength(2));
      expect(rows.every((c) => c.couponCents == 0), isTrue);
      expect(rows.every((c) => c.transactionId == null), isTrue);
      expect(await engine.getBalance('a1'), 0);
    });
  });

  group('processMaturities', () {
    test('marks a bond matured once the term ends', () async {
      await addAccount('a1');
      final bond = await createBond();

      expect(await service.processMaturities(now: DateTime(2030, 12, 31)), 0);
      expect((await dao.byId(bond.id))!.isMatured, isFalse);

      expect(await service.processMaturities(now: DateTime(2031, 1, 2)), 1);
      expect((await dao.byId(bond.id))!.isMatured, isTrue);

      expect(await service.processMaturities(now: DateTime(2031, 1, 2)), 0);
    });
  });

  group('forecasting', () {
    test('forecast values add the unpaid coupons to the balance', () async {
      await addAccount('a1');
      await seedBalance('a1', 100000);
      final bond = await createBond();

      final remaining = await service.remainingCouponDates(
          bond, now: DateTime(2026, 6, 15));
      expect(remaining, hasLength(5));
      expect(
          await service.forecastCouponCents(bond, now: DateTime(2026, 6, 15)),
          30000);
      expect(
        await service.forecastMaturityValue(bond, now: DateTime(2026, 6, 15)),
        130000,
      );
    });

    test('a fully-realized bond forecasts nothing more', () async {
      await addAccount('a1');
      await seedBalance('a1', 100000);
      final bond = await createBond();
      await service.processCoupons(now: DateTime(2032, 1, 2));

      expect(await service.remainingCouponDates(bond, now: DateTime(2032, 1, 2)),
          isEmpty);
      expect(
          await service.forecastCouponCents(bond, now: DateTime(2032, 1, 2)), 0);
      expect(
        await service.forecastMaturityValue(bond, now: DateTime(2032, 1, 2)),
        await engine.getBalance('a1'),
      );
    });
  });

  group('dao', () {
    test('archive hides a bond, reopen restores it', () async {
      await addAccount('a1');
      final bond = await createBond();

      await dao.archive(bond.id, nowMillis: clock + 1);
      expect(await dao.active(), isEmpty);
      expect(await dao.archived(), hasLength(1));

      await dao.reopen(bond.id, nowMillis: clock + 2);
      expect(await dao.active(), hasLength(1));
      expect(await dao.archived(), isEmpty);
    });
  });
}
