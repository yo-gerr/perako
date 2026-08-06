import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/ledger_dao.dart';
import 'package:perako/core/database/daos/savings_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/savings/domain/savings_interest_service.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late SavingsDao savingsDao;
  late SavingsInterestService service;
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
    savingsDao = SavingsDao(db);
    service = SavingsInterestService(
      db: db,
      engine: engine,
      savingsDao: savingsDao,
      ledgerDao: LedgerDao(db),
      accountsDao: AccountsDao(db),
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
          name: Value(id),
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

  Future<void> configure(
    String accountId, {
    double rate = 0.05,
    CompoundingFrequency frequency = CompoundingFrequency.monthly,
    int day = 1,
    required DateTime start,
    bool isPaused = false,
  }) async {
    await addAccount(accountId);
    await savingsDao.upsert(SavingsAccountsCompanion(
      accountId: Value(accountId),
      interestRate: Value(rate),
      compoundingFrequency: Value(frequency.name),
      interestCreditDay: Value(day),
      isPaused: Value(isPaused),
      startDate: Value(start.millisecondsSinceEpoch),
      updatedAt: Value(clock),
      version: const Value(1),
    ));
  }

  Future<void> deposit(String accountId, int cents, DateTime on) =>
      engine.postTransaction(
        description: 'deposit',
        on: on,
        lines: buildLedgerLines(
          type: TxType.income,
          accountId: accountId,
          amountCents: cents,
        ),
      );

  group('interestOn', () {
    test('computes simple interest over a 365-day year', () {
      expect(
        SavingsInterestService.interestOn(
          principalCents: 100000,
          annualRate: 0.05,
          days: 365,
        ),
        5000,
      );
    });

    test('rounds to the nearest cent', () {
      expect(
        SavingsInterestService.interestOn(
          principalCents: 100000,
          annualRate: 0.05,
          days: 1,
        ),
        14,
      );
    });

    test('earns nothing on non-positive principal or zero days', () {
      expect(
        SavingsInterestService.interestOn(
          principalCents: 0,
          annualRate: 0.05,
          days: 30,
        ),
        0,
      );
      expect(
        SavingsInterestService.interestOn(
          principalCents: -100,
          annualRate: 0.05,
          days: 30,
        ),
        0,
      );
      expect(
        SavingsInterestService.interestOn(
          principalCents: 100000,
          annualRate: 0.05,
          days: 0,
        ),
        0,
      );
    });
  });

  group('creditDatesBetween', () {
    test('daily covers every calendar day from the lower bound', () {
      final dates = SavingsInterestService.creditDatesBetween(
        start: DateTime(2026, 1, 1),
        frequency: CompoundingFrequency.daily,
        creditDay: 1,
        from: DateTime(2026, 1, 3),
        to: DateTime(2026, 1, 7),
      );
      expect(dates, hasLength(5));
      expect(dates.first, DateTime(2026, 1, 3));
      expect(dates.last, DateTime(2026, 1, 7));
    });

    test('monthly picks the credit day each month at or after the start', () {
      final dates = SavingsInterestService.creditDatesBetween(
        start: DateTime(2026, 1, 10),
        frequency: CompoundingFrequency.monthly,
        creditDay: 1,
        from: DateTime(2026, 2, 1),
        to: DateTime(2026, 3, 31),
      );
      expect(dates, [DateTime(2026, 2, 1), DateTime(2026, 3, 1)]);
    });

    test('monthly clamps the credit day to short months', () {
      final dates = SavingsInterestService.creditDatesBetween(
        start: DateTime(2026, 1, 10),
        frequency: CompoundingFrequency.monthly,
        creditDay: 31,
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 4, 30),
      );
      expect(dates, [DateTime(2026, 3, 31), DateTime(2026, 4, 30)]);
    });

    test('annually lands on the anniversary and clamps leap day', () {
      final dates = SavingsInterestService.creditDatesBetween(
        start: DateTime(2024, 2, 29),
        frequency: CompoundingFrequency.annually,
        creditDay: 1,
        from: DateTime(2025, 1, 1),
        to: DateTime(2027, 12, 31),
      );
      expect(dates, [
        DateTime(2025, 2, 28),
        DateTime(2026, 2, 28),
        DateTime(2027, 2, 28),
      ]);
    });
  });

  group('nextCreditDate', () {
    test('returns the next monthly credit strictly after the anchor', () {
      expect(
        SavingsInterestService.nextCreditDate(
          start: DateTime(2026, 1, 1),
          frequency: CompoundingFrequency.monthly,
          creditDay: 5,
          after: DateTime(2026, 1, 10),
        ),
        DateTime(2026, 2, 5),
      );
    });
  });

  group('ensureSchedules', () {
    test('seeds monthly credits from the start through the lookahead', () async {
      await configure('a1', start: DateTime(2026, 1, 1));
      await service.ensureSchedules(now: DateTime(2026, 3, 15, 12));

      final schedules = await savingsDao.schedulesFor('a1');
      final dates = [
        for (final s in schedules) DateTime.fromMillisecondsSinceEpoch(s.dueDate),
      ];
      expect(dates.first, DateTime(2026, 2, 1));
      expect(dates[1], DateTime(2026, 3, 1));
      // Feb, Mar, Apr, May, Jun (Jun 1 is within the ~92-day lookahead).
      expect(dates, hasLength(5));
    });

    test('is idempotent', () async {
      await configure('a1', start: DateTime(2026, 1, 1));
      await service.ensureSchedules(now: DateTime(2026, 3, 15, 12));
      await service.ensureSchedules(now: DateTime(2026, 3, 15, 12));

      final schedules = await savingsDao.schedulesFor('a1');
      expect(schedules, hasLength(5));
    });

    test('skips paused accounts', () async {
      await configure('a1', start: DateTime(2026, 1, 1), isPaused: true);
      await service.ensureSchedules(now: DateTime(2026, 3, 15, 12));

      expect(await savingsDao.schedulesFor('a1'), isEmpty);
    });

    test('seeds daily credits', () async {
      await configure(
        'a1',
        frequency: CompoundingFrequency.daily,
        start: DateTime(2026, 1, 1),
      );
      await service.ensureSchedules(now: DateTime(2026, 1, 3, 12));

      final schedules = await savingsDao.schedulesFor('a1');
      final dates = [
        for (final s in schedules) DateTime.fromMillisecondsSinceEpoch(s.dueDate),
      ];
      expect(dates.first, DateTime(2026, 1, 2));
      expect(dates.last, DateTime(2026, 4, 5));
    });
  });

  group('accrueDueInterest', () {
    test('posts monthly interest that compounds on the balance', () async {
      await configure('a1', rate: 0.05, start: DateTime(2026, 1, 1));
      await deposit('a1', 100000, DateTime(2026, 1, 5, 12));

      final credited = await service.accrueDueInterest(now: DateTime(2026, 3, 15, 12));

      expect(credited, 2);
      // Feb 1: 100000 * 0.05 * 31/365 = 424.66 -> 425.
      // Mar 1: (100000 + 425) * 0.05 * 28/365 = 385.19 -> 385.
      final balance = await engine.getBalance('a1');
      expect(balance, 100810);

      final schedules = await savingsDao.schedulesFor('a1');
      final feb = schedules.singleWhere(
          (s) => DateTime.fromMillisecondsSinceEpoch(s.dueDate) == DateTime(2026, 2, 1));
      final mar = schedules.singleWhere(
          (s) => DateTime.fromMillisecondsSinceEpoch(s.dueDate) == DateTime(2026, 3, 1));
      expect(feb.transactionId, isNotNull);
      expect(feb.interestCents, 425);
      expect(feb.principalCents, 100000);
      expect(mar.transactionId, isNotNull);
      expect(mar.interestCents, 385);
      expect(mar.principalCents, 100425);
    });

    test('is idempotent and realizes nothing twice', () async {
      await configure('a1', start: DateTime(2026, 1, 1));
      await deposit('a1', 100000, DateTime(2026, 1, 5, 12));

      await service.accrueDueInterest(now: DateTime(2026, 3, 15, 12));
      final again = await service.accrueDueInterest(now: DateTime(2026, 3, 15, 12));
      expect(again, 0);
      expect(await engine.getBalance('a1'), 100810);
    });

    test('earns nothing on an empty account and still advances the schedule',
        () async {
      await configure('a1', start: DateTime(2026, 1, 1));

      final credited = await service.accrueDueInterest(now: DateTime(2026, 3, 15, 12));

      expect(credited, 0);
      expect(await engine.getBalance('a1'), 0);
      final due = [
        for (final s in await savingsDao.schedulesFor('a1'))
          if (s.dueDate <= DateTime(2026, 3, 15).millisecondsSinceEpoch) s,
      ];
      expect(due, hasLength(2));
      expect(due.every((s) => s.transactionId == null), isTrue);
      expect(due.every((s) => s.interestCents == 0), isTrue);
    });

    test('paused accounts advance their schedule without posting', () async {
      await configure('a1', start: DateTime(2026, 1, 1));
      await deposit('a1', 100000, DateTime(2026, 1, 5, 12));
      // Seed schedules while active.
      await service.accrueDueInterest(now: DateTime(2026, 1, 10, 12));
      // Pause before any credit is due.
      await savingsDao.upsert(SavingsAccountsCompanion(
        accountId: const Value('a1'),
        interestRate: const Value(0.05),
        compoundingFrequency: const Value('monthly'),
        interestCreditDay: const Value(1),
        isPaused: const Value(true),
        startDate: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
        updatedAt: Value(clock + 1),
        version: const Value(2),
      ));

      final credited = await service.accrueDueInterest(now: DateTime(2026, 3, 15, 12));

      expect(credited, 0);
      expect(await engine.getBalance('a1'), 100000);
      final schedules = await savingsDao.schedulesFor('a1');
      expect(schedules, isNotEmpty);
      expect(schedules.every((s) => s.transactionId == null), isTrue);
      expect(schedules.every((s) => s.interestCents == 0), isTrue);
    });

    test('does not credit interest on a negative balance', () async {
      await configure('a1', start: DateTime(2026, 1, 1));
      // Overdrawn account: expense larger than the deposit.
      await deposit('a1', 50000, DateTime(2026, 1, 5, 12));
      await engine.postTransaction(
        description: 'withdrawal',
        on: DateTime(2026, 1, 6, 12),
        lines: buildLedgerLines(
          type: TxType.expense,
          accountId: 'a1',
          amountCents: 80000,
        ),
      );

      final credited = await service.accrueDueInterest(now: DateTime(2026, 3, 15, 12));

      expect(credited, 0);
      expect(await engine.getBalance('a1'), -30000);
    });
  });
}
