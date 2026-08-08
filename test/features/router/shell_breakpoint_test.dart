import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_test_harness.dart';

void main() {
  testWidgets('layout switches between bottom bar, rail, and sidebar',
      (tester) async {
    // Narrow: bottom navigation bar with the More page.
    await pumpSignedInShell(tester, size: const Size(1000, 900));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);

    // Medium: icon rail, no bottom bar, no labels.
    await resizeSurface(tester, const Size(1100, 900));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    // The rail alone cannot expand the sidebar; that needs a wide surface.
    expect(find.byTooltip('Expand sidebar'), findsNothing);

    // Wide: expanded sidebar with labels.
    await resizeSurface(tester, const Size(1400, 900));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);

    // Manual collapse overrides width-based expansion.
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byTooltip('Dashboard'), findsOneWidget);

    // Re-expanding restores the labeled sidebar.
    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);

    // Back down to medium again: the rail returns.
    await resizeSurface(tester, const Size(1100, 900));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsNothing);
    expect(find.byTooltip('Dashboard'), findsOneWidget);
  });
}
