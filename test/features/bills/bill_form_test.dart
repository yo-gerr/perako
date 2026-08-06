import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/bills/domain/bill_service.dart';
import 'package:perako/features/bills/presentation/screens/bill_form_screen.dart';
import 'package:perako/features/bills/presentation/providers/bills_providers.dart';

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
    await db.into(db.categories).insert(CategoriesCompanion(
          id: const Value('housing'),
          name: const Value('Housing'),
          type: const Value('expense'),
          color: const Value('indigo'),
          icon: const Value('home'),
          updatedAt: const Value(1),
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
              builder: (c, s) => const BillFormScreen(),
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

  testWidgets('validates name, amount, account, and day of month',
      (tester) async {
    await seed();
    await pumpForm(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Rent');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Amount'), '1500');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Pick the account to pay from.'), findsOneWidget);

    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a day of the month (1-31).'), findsOneWidget);
  });

  testWidgets('creates a monthly bill with the expected schedule',
      (tester) async {
    await seed();
    await pumpForm(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Rent');
    await tester.enterText(
        find.widgetWithText(TextField, 'Amount'), '1500');
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Housing').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Day of the month'), '5');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);

    final rows = await db.select(db.bills).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Rent');
    expect(rows.single.amountCents, 150000);
    expect(rows.single.accountId, 'checking');
    expect(rows.single.categoryId, 'housing');
    expect(rows.single.frequency, 'monthly');
    expect(rows.single.dayOfMonth, 5);
    final expected = container
        .read(billServiceProvider)
        .initialDueDate(BillFrequency.monthly, 5);
    expect(rows.single.nextDueDate,
        expected.millisecondsSinceEpoch);
  });
}
