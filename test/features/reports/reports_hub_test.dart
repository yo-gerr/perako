import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/reports/presentation/screens/net_worth_report_screen.dart';
import 'package:perako/features/reports/presentation/screens/reports_hub_screen.dart';

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

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hub lists all five report types', (tester) async {
    await pump(tester, const ReportsHubScreen());

    expect(find.text('Net Worth'), findsOneWidget);
    expect(find.text('Cash Flow'), findsOneWidget);
    expect(find.text('Spending by Category'), findsOneWidget);
    expect(find.text('Income by Category'), findsOneWidget);
    expect(find.text('Budget Performance'), findsOneWidget);
  });

  testWidgets('net worth report renders its summary with no data',
      (tester) async {
    await pump(tester, const NetWorthReportScreen());

    expect(find.text('Net Worth Report'), findsOneWidget);
    expect(find.text('Current net worth'), findsOneWidget);
    expect(find.text('₱0.00'), findsWidgets);
    // The range selector presets are visible.
    expect(find.text('3M'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });
}
