import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/shell_test_harness.dart';

void main() {
  testWidgets('wide surface collapses the sidebar to an icon rail and back',
      (tester) async {
    await pumpSignedInShell(tester, size: const Size(1400, 900));

    // Expanded sidebar with labels and a collapse affordance.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    // Collapsed to the icon rail: labels gone, an expand affordance remains.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);

    // Rail navigation still works while collapsed.
    await tester.tap(find.byTooltip('Categories'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Categories'), findsOneWidget);

    // Expanding restores the labeled sidebar.
    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Expand sidebar'), findsNothing);
  });

  testWidgets('collapsed state is persisted and restored on restart',
      (tester) async {
    await pumpSignedInShell(tester, size: const Size(1400, 900));
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    // The choice was written to shared_preferences.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.sidebarCollapsed'), isTrue);

    // A fresh boot reading that persisted value opens collapsed.
    await pumpSignedInShell(
      tester,
      size: const Size(1400, 900),
      initialPrefs: {'settings.sidebarCollapsed': true},
    );
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);
  });
}
