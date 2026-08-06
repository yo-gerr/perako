import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/core/widgets/currency_scope.dart';
import 'package:perako/features/savings/presentation/screens/savings_detail_screen.dart';

void main() {
  testWidgets('renders balance, forecast, and credit history', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 2, 1);

    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('a1'),
          name: const Value('Rainy Day'),
          type: const Value('savings'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
          version: const Value(1),
        ));

    await db.into(db.savingsAccounts).insert(SavingsAccountsCompanion(
          accountId: const Value('a1'),
          interestRate: const Value(0.05),
          compoundingFrequency: const Value('monthly'),
          interestCreditDay: const Value(1),
          isPaused: const Value(false),
          startDate: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
          version: const Value(1),
        ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CurrencyScope(
          symbol: '₱',
          child: MaterialApp(
            home: SavingsDetailScreen(accountId: 'a1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rainy Day'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('5.00% p.a.'), findsOneWidget);
    expect(find.text('12-month forecast'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Interest credits'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Interest credits'), findsOneWidget);
  });

  testWidgets('shows setup card when savings are not configured', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 2, 1);

    await db.into(db.accounts).insert(AccountsCompanion(
          id: const Value('a2'),
          name: const Value('Plain Account'),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('blue'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
          version: const Value(1),
        ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const CurrencyScope(
          symbol: '₱',
          child: MaterialApp(
            home: SavingsDetailScreen(accountId: 'a2'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not configured as a savings account'), findsOneWidget);
    expect(find.text('Set up savings'), findsOneWidget);
  });
}
