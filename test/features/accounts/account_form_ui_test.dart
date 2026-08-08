import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/accounts/presentation/screens/account_form_screen.dart';

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

  Future<void> pumpForm(WidgetTester tester, {String? accountId}) async {
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'form',
              builder: (c, s) => AccountFormScreen(accountId: accountId),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> seedAccount({
    required String id,
    required String color,
    required String icon,
  }) async {
    await db.into(db.accounts).insert(AccountsCompanion(
          id: Value(id),
          name: const Value('Wallet'),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: Value(color),
          icon: Value(icon),
          isArchived: const Value(false),
          openingDate: Value(1),
          updatedAt: Value(1),
          version: const Value(1),
        ));
  }

  testWidgets('renders a bold in-body title and no app bar', (tester) async {
    await pumpForm(tester);

    expect(find.byType(AppBar), findsNothing);
    final title = tester.widget<Text>(find.text('New account'));
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('back button pops the form', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('icon picker: search narrows the library and the choice persists',
      (tester) async {
    await pumpForm(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Wallet');

    await tester.tap(find.text('Icon'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose icon'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('icon-search-field')), 'cart');
    await tester.pumpAndSettle();

    final cartIcon = find.byIcon(FontAwesomeIcons.cartShopping.data);
    expect(cartIcon, findsOneWidget);
    await tester.tap(cartIcon);
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose icon'), findsNothing);

    final create = find.text('Create');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    final rows = await db.select(db.accounts).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Wallet');
    expect(rows.single.icon, 'cart');
  });

  testWidgets('custom color: hex entry is persisted', (tester) async {
    await pumpForm(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Wallet');

    await tester.tap(find.byKey(const Key('custom-color-swatch')));
    await tester.pumpAndSettle();
    expect(find.text('Custom color'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('custom-color-hex')), '#FFA500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Custom color'), findsNothing);

    final create = find.text('Create');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    final rows = await db.select(db.accounts).get();
    expect(rows, hasLength(1));
    expect(rows.single.color, '#FFA500');
  });

  testWidgets('editing loads the stored icon and hex color', (tester) async {
    await seedAccount(id: 'acc_wallet', color: '#336699', icon: 'coins');
    await pumpForm(tester, accountId: 'acc_wallet');

    expect(find.text('Edit account'), findsOneWidget);
    expect(find.text('coins'), findsOneWidget);

    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    final rows = await db.select(db.accounts).get();
    expect(rows, hasLength(1));
    expect(rows.single.icon, 'coins');
    expect(rows.single.color, '#336699');
  });
}
