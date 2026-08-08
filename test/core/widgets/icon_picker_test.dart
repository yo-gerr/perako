import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:perako/core/widgets/icon_picker.dart';
import 'package:perako/features/accounts/presentation/account_style.dart';

void main() {
  test('iconGridColumns adapts to width and caps on wide screens', () {
    expect(iconGridColumns(200), 4);
    expect(iconGridColumns(320), 5);
    expect(iconGridColumns(360), 5);
    expect(iconGridColumns(800), 8);
    expect(iconGridColumns(1200), 8);
  });

  test('iconGridScrollOffset targets the selected row', () {
    // 520 grid, 8 columns: tile = (520-32-56)/8 = 54; row stride = 62.
    expect(
      iconGridScrollOffset(index: 0, columns: 8, width: 800),
      closeTo(4.0, 0.001),
    );
    expect(
      iconGridScrollOffset(index: 8, columns: 8, width: 800),
      closeTo(66.0, 0.001), // row 1
    );
    expect(
      iconGridScrollOffset(index: 24, columns: 8, width: 800),
      closeTo(190.0, 0.001), // row 3
    );
    // 360 phone, 5 columns: tile = (360-32-32)/5 = 59.2; row stride = 67.2.
    expect(
      iconGridScrollOffset(index: 0, columns: 5, width: 360),
      closeTo(4.0, 0.001),
    );
    expect(
      iconGridScrollOffset(index: 8, columns: 5, width: 360),
      closeTo(71.2, 0.001), // row 1
    );
  });

  Future<void> openSheet(WidgetTester tester,
      {ValueChanged<String>? onChanged}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showIconPickerSheet(
                context,
                selected: 'wallet',
                onChanged: onChanged ?? (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('icons are centered within their tiles', (tester) async {
    await openSheet(tester);

    final icon = find.byIcon(Icons.account_balance_wallet);
    final tile = find.ancestor(of: icon, matching: find.byType(InkWell)).first;

    final iconCenter = tester.getCenter(icon);
    final tileRect = tester.getRect(tile);

    expect((iconCenter.dx - tileRect.center.dx).abs(), lessThan(1.0));
    expect((iconCenter.dy - tileRect.center.dy).abs(), lessThan(1.0));
  });

  testWidgets('typing shows a clear button; clearing restores the grid',
      (tester) async {
    await openSheet(tester);

    expect(find.byKey(const Key('icon-search-clear')), findsNothing);

    await tester.enterText(find.byKey(const Key('icon-search-field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('icon-search-clear')), findsOneWidget);
    expect(find.text('No icons match your search.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('icon-search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('icon-search-clear')), findsNothing);
    expect(find.text('No icons match your search.'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('empty search offers a way back', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(const Key('icon-search-field')), 'nope');
    await tester.pumpAndSettle();
    expect(find.text('No icons match your search.'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No icons match your search.'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('the title reports the result count', (tester) async {
    await openSheet(tester);

    expect(find.text('Choose icon · ${iconCatalog.length}'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('icon-search-field')), 'cart');
    await tester.pumpAndSettle();
    expect(find.text('Choose icon · 1'), findsOneWidget);
  });

  testWidgets('picking an icon closes the sheet and reports the name',
      (tester) async {
    String? picked;
    await openSheet(tester, onChanged: (v) => picked = v);

    await tester.enterText(find.byKey(const Key('icon-search-field')), 'cart');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FontAwesomeIcons.cartShopping.data));
    await tester.pumpAndSettle();

    expect(picked, 'cart');
    expect(find.textContaining('Choose icon'), findsNothing);
  });
}
