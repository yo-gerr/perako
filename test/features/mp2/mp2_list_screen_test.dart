import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/mp2_dao.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/core/widgets/currency_scope.dart';
import 'package:perako/features/mp2/presentation/screens/mp2_list_screen.dart';

void main() {
  Future<AppDatabase> seed({
    required DateTime startDate,
    required DateTime maturityDate,
    String label = 'My MP2',
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final dao = Mp2Dao(db);
    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('a1'),
          name: const Value('Cebu Savings'),
          type: const Value('savings'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(startDate.millisecondsSinceEpoch),
          updatedAt: Value(startDate.millisecondsSinceEpoch),
          version: const Value(1),
        ));
    await dao.insert(Mp2AccountsCompanion(
      id: const Value('m1'),
      accountId: const Value('a1'),
      label: Value(label),
      dividendRate: const Value(0.07),
      startDate: Value(startDate.millisecondsSinceEpoch),
      maturityDate: Value(maturityDate.millisecondsSinceEpoch),
      isMatured: const Value(false),
      createdAt: Value(startDate.millisecondsSinceEpoch),
      updatedAt: Value(startDate.millisecondsSinceEpoch),
      version: const Value(1),
    ));
    return db;
  }

  testWidgets('renders an active MP2 account with its term countdown',
      (tester) async {
    final today = DateTime.now();
    final db = await seed(
      startDate: today,
      maturityDate: DateTime(today.year + 5, today.month, today.day),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CurrencyScope(
          symbol: '₱',
          child: MaterialApp(home: Mp2ListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final daysLeft = DateTime(today.year + 5, today.month, today.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    expect(find.text('MP2'), findsOneWidget);
    expect(find.text('My MP2'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
    expect(find.textContaining('$daysLeft days left in term'), findsOneWidget);
  });

  testWidgets('shows the banner when a term ends within 30 days',
      (tester) async {
    final today = DateTime.now();
    final maturity = today.add(const Duration(days: 3));
    final start = DateTime(maturity.year - 5, maturity.month, maturity.day);
    final db = await seed(startDate: start, maturityDate: maturity);
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CurrencyScope(
          symbol: '₱',
          child: MaterialApp(home: Mp2ListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 term ends within 30 days'), findsOneWidget);
    expect(find.textContaining('3 days left in term'), findsOneWidget);
  });
}
