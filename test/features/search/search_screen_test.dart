import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/search/presentation/screens/search_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int clock;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    idCounter = 0;
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SearchScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<String> seedAccount(String id, String name) async {
    await db.into(db.accounts).insert(AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: const Value('checking'),
      currency: const Value('PHP'),
      color: const Value('blue'),
      icon: const Value('wallet'),
      isArchived: const Value(false),
      openingDate: Value(clock),
      updatedAt: Value(clock),
      version: const Value(1),
    ));
    return id;
  }

  Future<void> seedIncome(String description) async {
    await seedAccount('checking', 'Everyday Wallet');
    await LedgerEngine(
      db: db,
      idGenerator: nextId,
      clock: () => clock,
    ).postTransaction(
      description: description,
      on: DateTime(2026, 1, 5, 12),
      lines: const [
        LedgerLine(
          accountId: 'checking',
          type: EntryType.debit,
          amountCents: 100000,
        ),
        LedgerLine(
          accountId: 'counterparty_income',
          type: EntryType.credit,
          amountCents: 100000,
          categoryId: 'salary',
        ),
      ],
    );
  }

  Future<void> seedTag(String id, String name) async {
    await db.into(db.tags).insert(TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: const Value('teal'),
      updatedAt: Value(clock),
      version: const Value(1),
    ));
  }

  Future<void> typeAndSettle(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a hint before any term is typed', (tester) async {
    await pump(tester);

    expect(
      find.textContaining('Search transactions, accounts, bills'),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('typing renders matching transaction hits', (tester) async {
    await seedIncome('January payroll');
    await pump(tester);

    await typeAndSettle(tester, 'payroll');

    expect(find.text('January payroll'), findsOneWidget);
    expect(find.textContaining('Everyday Wallet'), findsOneWidget);
    // Income amounts render as +₱1000.00.
    expect(find.text('+₱1000.00'), findsOneWidget);
    expect(find.text('No results for "payroll".'), findsNothing);
  });

  testWidgets('clearing the term restores the hint', (tester) async {
    await seedIncome('January payroll');
    await pump(tester);

    await typeAndSettle(tester, 'payroll');
    expect(find.text('January payroll'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('January payroll'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('type chips restrict which entities are searched',
      (tester) async {
    await seedAccount('savings', 'Savings Bank');
    await seedIncome('January payroll');
    await pump(tester);

    await typeAndSettle(tester, 'savings');
    // The account name matches, so an account hit renders.
    expect(find.text('Savings Bank'), findsOneWidget);

    // Restrict to transactions only: the account hit disappears.
    final chip = find.descendant(
      of: find.byType(ChoiceChip),
      matching: find.text('Transactions'),
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('Savings Bank'), findsNothing);
  });

  testWidgets('no tag chip is shown when no tags exist', (tester) async {
    await pump(tester);

    expect(find.text('Tag'), findsNothing);
  });

  testWidgets('tag filter chip appears when tags exist', (tester) async {
    await seedTag('tag_work', 'work');
    await pump(tester);

    expect(find.text('Tag'), findsOneWidget);
  });
}
