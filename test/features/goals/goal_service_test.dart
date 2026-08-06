import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/goals_dao.dart';
import 'package:perako/features/goals/domain/goal_service.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';

void main() {
  late AppDatabase db;
  late GoalsDao goalsDao;
  late LedgerEngine engine;
  late GoalService service;
  late int clock;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    goalsDao = GoalsDao(db);
    engine = LedgerEngine(db: db, idGenerator: nextId, clock: () => clock);
    service = GoalService(db: db, engine: engine, goalsDao: goalsDao);
  });

  tearDown(() async {
    await db.close();
    idCounter = 0;
  });

  Future<Goal> insertGoal({
    String name = 'Emergency fund',
    String type = 'savings',
    int targetAmountCents = 100000,
    int currentAmountCents = 0,
    int? targetDate,
    int createdAt = 100,
    bool isCompleted = false,
  }) {
    return goalsDao.insert(GoalsCompanion(
      id: Value(nextId()),
      name: Value(name),
      type: Value(type),
      targetAmountCents: Value(targetAmountCents),
      currentAmountCents: Value(currentAmountCents),
      targetDate: Value(targetDate),
      fundingAccountId: const Value('dst'),
      isCompleted: Value(isCompleted),
      createdAt: Value(createdAt),
      updatedAt: Value(createdAt),
      version: const Value(1),
    ));
  }

  group('contribute', () {
    test('posts a balanced transfer into the funding account', () async {
      final goal = await insertGoal();
      final txId = await service.contribute(
        goal,
        sourceAccountId: 'src',
        amountCents: 25000,
        on: DateTime(2026, 3, 15, 12),
      );

      // Source credited, funding account debited.
      expect(await engine.getBalance('src'), -25000);
      expect(await engine.getBalance('dst'), 25000);

      // Contribution history links the posting.
      final contributions = await goalsDao.contributionsFor(goal.id);
      expect(contributions, hasLength(1));
      expect(contributions.single.transactionId, txId);
      expect(contributions.single.amountCents, 25000);
      expect(contributions.single.contributedOn,
          DateTime(2026, 3, 15, 12).millisecondsSinceEpoch);

      // The goal's current amount advanced.
      final updated = await goalsDao.byId(goal.id);
      expect(updated!.currentAmountCents, 25000);
      expect(updated.isCompleted, isFalse);
    });

    test('contributing twice accumulates and posts two transfers', () async {
      final goal = await insertGoal();
      await service.contribute(
          goal, sourceAccountId: 'src', amountCents: 30000);
      await service.contribute(
          goal, sourceAccountId: 'src', amountCents: 20000);

      expect(await engine.getBalance('src'), -50000);
      expect(await engine.getBalance('dst'), 50000);
      expect(await goalsDao.contributionsFor(goal.id), hasLength(2));

      final updated = await goalsDao.byId(goal.id);
      expect(updated!.currentAmountCents, 50000);
    });

    test('marks the goal complete when the target is reached', () async {
      final goal = await insertGoal(targetAmountCents: 50000);
      await service.contribute(
          goal, sourceAccountId: 'src', amountCents: 50000);

      final updated = await goalsDao.byId(goal.id);
      expect(updated!.currentAmountCents, 50000);
      expect(updated.isCompleted, isTrue);
    });
  });

  group('progress', () {
    test('derives ratio, remaining, and day windows', () async {
      final createdAt = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final goal = await insertGoal(
        targetAmountCents: 10000,
        currentAmountCents: 5000,
        createdAt: createdAt,
        targetDate: DateTime(2026, 4, 1).millisecondsSinceEpoch,
      );

      final p = service.progress(goal, now: DateTime(2026, 3, 1, 12));
      expect(p.currentCents, 5000);
      expect(p.targetCents, 10000);
      expect(p.ratio, 0.5);
      expect(p.remainingCents, 5000);
      expect(p.daysElapsed, 59);
      expect(p.daysLeft, 31);
      expect(p.isComplete, isFalse);
    });

    test('uses a 12-month default horizon without a target date', () async {
      final createdAt = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final goal = await insertGoal(createdAt: createdAt);
      final p = service.progress(goal, now: DateTime(2026, 3, 1));
      expect(p.daysLeft, 365 - 59);
    });
  });

  group('forecastCompletion', () {
    test('estimates completion from the average contribution rate',
        () async {
      final createdAt = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final goal = await insertGoal(
        targetAmountCents: 10000,
        currentAmountCents: 5000,
        createdAt: createdAt,
      );

      final forecast =
          service.forecastCompletion(goal, now: DateTime(2026, 3, 1));
      expect(forecast, isNotNull);
      expect(forecast!.year, 2026);
      expect(forecast.month, 4);
      expect(forecast.day, 30);
    });

    test('returns null when there is no progress yet', () async {
      final goal = await insertGoal(currentAmountCents: 0);
      expect(
          service.forecastCompletion(goal, now: DateTime(2026, 3, 1)), isNull);
    });
  });

  group('suggestedMonthlyContribution', () {
    test('returns the remaining amount when less than a month is left',
        () async {
      final goal = await insertGoal(
        targetAmountCents: 10000,
        currentAmountCents: 0,
        targetDate: DateTime(2026, 3, 15).millisecondsSinceEpoch,
      );
      expect(service.suggestedMonthlyContribution(goal,
              now: DateTime(2026, 2, 15)),
          10000);
    });

    test('spreads the remaining amount over the months available', () async {
      final goal = await insertGoal(
        targetAmountCents: 120000,
        currentAmountCents: 0,
        targetDate: DateTime(2026, 5, 15).millisecondsSinceEpoch,
      );
      // Roughly two months away, so about half per month.
      final suggested = service.suggestedMonthlyContribution(goal,
          now: DateTime(2026, 3, 15));
      expect(suggested, inInclusiveRange(58000, 62000));
    });

    test('returns zero when the goal is complete', () async {
      final goal = await insertGoal(
        targetAmountCents: 10000,
        currentAmountCents: 10000,
        isCompleted: true,
      );
      expect(service.suggestedMonthlyContribution(goal,
              now: DateTime(2026, 3, 1)),
          0);
    });
  });
}
