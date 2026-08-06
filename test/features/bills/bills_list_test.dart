import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/bills/presentation/screens/bills_list_screen.dart';

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

  Future<void> insertBill(String name, {int nextDueDate = 1}) async {
    await db.into(db.bills).insert(BillsCompanion(
          id: Value('bil_$name'),
          name: Value(name),
          accountId: const Value('a1'),
          categoryId: const Value(null),
          amountCents: const Value(150000),
          frequency: const Value('monthly'),
          dayOfMonth: const Value(1),
          nextDueDate: Value(nextDueDate),
          createdAt: const Value(1),
          updatedAt: const Value(1),
          version: const Value(1),
        ));
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BillsListScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows an active bill with amount and due status',
      (tester) async {
    await insertBill('Internet');
    await pumpList(tester);

    expect(find.text('Internet'), findsOneWidget);
    expect(find.textContaining('₱1500.00'), findsWidgets);
    expect(find.text('Monthly · ₱1500.00'), findsOneWidget);
  });

  testWidgets('archives a bill via long-press and reopens it',
      (tester) async {
    await insertBill('Internet');
    await pumpList(tester);

    await tester.longPress(find.text('Internet'));
    await tester.pumpAndSettle();
    expect(find.text('Archive bill?'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Internet'), findsNothing);
    expect(find.text('No bills yet.\nUse + to add one.'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Internet'), findsOneWidget);

    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Internet'), findsOneWidget);
  });
}
