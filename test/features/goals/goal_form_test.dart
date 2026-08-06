import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/goals/presentation/screens/goal_form_screen.dart';

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

  Future<void> seed() async {
    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('dst'),
          name: const Value('Savings'),
          type: const Value('savings'),
          currency: const Value('PHP'),
          color: const Value('teal'),
          icon: const Value('savings'),
          isArchived: const Value(false),
          openingDate: Value(1),
          updatedAt: Value(1),
          version: const Value(1),
        ));
  }

  Future<void> pumpForm(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'form',
              builder: (c, s) => const GoalFormScreen(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('requires a name, amount, and a funding account',
      (tester) async {
    await seed();
    await pumpForm(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Vacation');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Target amount'), '1000');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Pick the account to fund the goal.'), findsOneWidget);
  });

  testWidgets('creates a savings goal and persists the row', (tester) async {
    await seed();
    await pumpForm(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Vacation');
    await tester.enterText(
        find.widgetWithText(TextField, 'Target amount'), '1000');
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Popped back to the home route.
    expect(find.text('home'), findsOneWidget);

    final rows = await db.select(db.goals).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Vacation');
    expect(rows.single.type, 'savings');
    expect(rows.single.targetAmountCents, 100000);
    expect(rows.single.currentAmountCents, 0);
    expect(rows.single.fundingAccountId, 'dst');
    expect(rows.single.targetDate, isNull);
    expect(rows.single.isCompleted, isFalse);
  });
}
