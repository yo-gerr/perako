import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_test_harness.dart';

void main() {
  testWidgets('medium surface shows an icon rail with tooltip navigation',
      (tester) async {
    await pumpSignedInShell(tester, size: const Size(1100, 900));

    // The rail replaces the bottom navigation bar and shows no labels.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byTooltip('PeraKo'), findsOneWidget);
    expect(find.byTooltip('Dashboard'), findsOneWidget);

    // Navigate through the rail by tooltip.
    await tester.tap(find.byTooltip('Categories'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Categories'), findsOneWidget);

    // The rail stays visible and other destinations remain reachable.
    expect(find.byTooltip('Bonds'), findsOneWidget);
    await tester.tap(find.byTooltip('Bonds'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Bonds'), findsOneWidget);
  });
}
