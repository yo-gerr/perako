import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/time_deposits_dao.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/core/widgets/currency_scope.dart';
import 'package:perako/features/time_deposits/presentation/screens/time_deposits_list_screen.dart';

void main() {
  testWidgets('renders an active deposit with its maturity countdown',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = TimeDepositsDao(db);
    final now = DateTime(2026, 2, 1);

    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('a1'),
          name: const Value('Cebu Savings'),
          type: const Value('savings'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
          version: const Value(1),
        ));
    await dao.insert(TimeDepositsCompanion(
      id: const Value('td1'),
      accountId: const Value('a1'),
      label: const Value('1-yr TD'),
      principalCents: const Value(100000),
      interestRate: const Value(0.06),
      interestMethod: const Value('simple'),
      startDate: Value(now.millisecondsSinceEpoch),
      maturityDate: Value(DateTime(2027, 2, 1).millisecondsSinceEpoch),
      maturityValueCents: const Value(106000),
      isMatured: const Value(false),
      createdAt: Value(now.millisecondsSinceEpoch),
      updatedAt: Value(now.millisecondsSinceEpoch),
      version: const Value(1),
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CurrencyScope(
          symbol: '₱',
          child: MaterialApp(home: TimeDepositsListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final daysLeft = DateTime(2027, 2, 1)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    expect(find.text('Time Deposits'), findsOneWidget);
    expect(find.text('1-yr TD'), findsOneWidget);
    expect(find.textContaining('$daysLeft days to maturity'), findsOneWidget);
    expect(find.text('₱1060.00'), findsOneWidget);
  });

  testWidgets('shows the banner when a deposit matures within a week',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = TimeDepositsDao(db);
    final today = DateTime.now();
    final start = DateTime(today.year - 1, today.month, today.day);
    final maturity = today.add(const Duration(days: 3));

    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('a1'),
          name: const Value('Cebu Savings'),
          type: const Value('savings'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(start.millisecondsSinceEpoch),
          updatedAt: Value(start.millisecondsSinceEpoch),
          version: const Value(1),
        ));
    await dao.insert(TimeDepositsCompanion(
      id: const Value('td2'),
      accountId: const Value('a1'),
      label: const Value('Near-maturity TD'),
      principalCents: const Value(100000),
      interestRate: const Value(0.06),
      interestMethod: const Value('simple'),
      startDate: Value(start.millisecondsSinceEpoch),
      maturityDate: Value(maturity.millisecondsSinceEpoch),
      maturityValueCents: const Value(106000),
      isMatured: const Value(false),
      createdAt: Value(start.millisecondsSinceEpoch),
      updatedAt: Value(start.millisecondsSinceEpoch),
      version: const Value(1),
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CurrencyScope(
          symbol: '₱',
          child: MaterialApp(home: TimeDepositsListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('matures within a week'), findsOneWidget);
    expect(find.textContaining('3 days to maturity'), findsOneWidget);
  });
}
