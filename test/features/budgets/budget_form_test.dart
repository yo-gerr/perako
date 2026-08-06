import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/budgets/presentation/screens/budget_form_screen.dart';

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
    await db.into(db.categories).insert(CategoriesCompanion(
          id: const Value('food'),
          name: const Value('Food'),
          type: const Value('expense'),
          color: const Value('orange'),
          icon: const Value('restaurant'),
          updatedAt: const Value(1),
        ));
    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('checking'),
          name: const Value('Checking'),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('teal'),
          icon: const Value('wallet'),
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
              builder: (c, s) => const BudgetFormScreen(),
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

  testWidgets('requires a name, amount, and a category or account',
      (tester) async {
    await seed();
    await pumpForm(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Food');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '100');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a category or an account to track.'), findsOneWidget);
  });

  testWidgets('creates a category budget with rollover', (tester) async {
    await seed();
    await pumpForm(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Groceries');
    await tester.enterText(
        find.widgetWithText(TextField, 'Amount'), '500');
    await tester.tap(find.text('None').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roll over unused budget'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Popped back to the home route.
    expect(find.text('home'), findsOneWidget);

    final rows = await db.select(db.budgets).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Groceries');
    expect(rows.single.amountCents, 50000);
    expect(rows.single.categoryId, 'food');
    expect(rows.single.accountId, isNull);
    expect(rows.single.rollover, isTrue);
    expect(rows.single.period, 'monthly');
  });
}
