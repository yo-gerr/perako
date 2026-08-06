import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/budgets/presentation/screens/budgets_list_screen.dart';

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

  Future<void> insertBudget(String name, int amountCents) async {
    await db.into(db.budgets).insert(BudgetsCompanion(
          id: Value('bgt_$name'),
          name: Value(name),
          amountCents: Value(amountCents),
          period: const Value('monthly'),
          categoryId: const Value(null),
          accountId: const Value(null),
          rollover: const Value(false),
          createdAt: const Value(1),
          updatedAt: const Value(1),
          version: const Value(1),
        ));
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsListScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows an active budget with spent / amount', (tester) async {
    await insertBudget('Groceries', 50000);
    await pumpList(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.textContaining('₱0.00 / ₱500.00'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('long-press archives a budget and it moves to archived',
      (tester) async {
    await insertBudget('Groceries', 50000);
    await pumpList(tester);

    await tester.longPress(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(find.text('Archive budget?'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsNothing);
    expect(find.text('No budgets yet.\nUse + to create one.'), findsOneWidget);

    // Switch to the archived segment and reopen it.
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
  });
}
