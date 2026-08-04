import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/accounts/presentation/screens/accounts_list_screen.dart';

Finder tileNamed(String name) => find.byWidgetPredicate(
    (w) => w is ListTile && w.title is Text && (w.title as Text).data == name);

void main() {
  late AppDatabase db;
  late AccountsDao dao;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = AccountsDao(db);
    final now = DateTime(2026, 1, 15).millisecondsSinceEpoch;
    for (final (id, name, type) in [
      ('acc_cash', 'Cash', 'cash'),
      ('acc_savings', 'Savings', 'savings'),
    ]) {
      await dao.insertAccount(AccountsCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type),
        currency: const Value('PHP'),
        color: const Value('teal'),
        icon: const Value('wallet'),
        isArchived: const Value(false),
        openingDate: Value(now),
        updatedAt: Value(now),
        version: const Value(1),
      ));
    }

    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountsListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('archived accounts are hidden, listed, and reopenable',
      (tester) async {
    await pump(tester);

    expect(tileNamed('Cash'), findsOneWidget);
    expect(tileNamed('Savings'), findsOneWidget);

    // Archive the savings account: it leaves the active list.
    await dao.archive('acc_savings', nowMillis: 1000);
    await tester.pumpAndSettle();
    expect(tileNamed('Savings'), findsNothing);

    // Switch to the Archived filter.
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(tileNamed('Savings'), findsOneWidget);

    // Reopen it back into the active list.
    await tester.tap(find.byIcon(Icons.restore));
    await tester.pumpAndSettle();
    expect(tileNamed('Savings'), findsNothing);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(tileNamed('Savings'), findsOneWidget);
  });
}
