import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/goals/presentation/screens/goals_list_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insertGoal(String name,
      {int currentAmountCents = 50000, int targetAmountCents = 100000}) async {
    await db.into(db.goals).insert(GoalsCompanion(
          id: Value('goal_$name'),
          name: Value(name),
          type: const Value('savings'),
          targetAmountCents: Value(targetAmountCents),
          currentAmountCents: Value(currentAmountCents),
          fundingAccountId: const Value('dst'),
          isCompleted: const Value(false),
          createdAt: const Value(1),
          updatedAt: const Value(1),
          version: const Value(1),
        ));
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GoalsListScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows an active goal with amount and progress',
      (tester) async {
    await insertGoal('Vacation');
    await pumpList(tester);

    expect(find.text('Vacation'), findsOneWidget);
    expect(find.text('Savings · ₱500.00 / ₱1000.00'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('₱500.00 to go'), findsOneWidget);
  });

  testWidgets('archives a goal via long-press and reopens it',
      (tester) async {
    await insertGoal('Vacation');
    await pumpList(tester);

    await tester.longPress(find.text('Vacation'));
    await tester.pumpAndSettle();
    expect(find.text('Archive goal?'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Vacation'), findsNothing);
    expect(find.text('No goals yet.\nUse + to create one.'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Vacation'), findsOneWidget);

    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Vacation'), findsOneWidget);
  });
}
