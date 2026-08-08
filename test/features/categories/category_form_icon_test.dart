import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/providers/core_providers.dart';
import 'package:perako/features/categories/presentation/screens/category_form_screen.dart';

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

  Future<void> pumpForm(WidgetTester tester, {String? categoryId}) async {
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'form',
              builder: (c, s) => CategoryFormScreen(categoryId: categoryId),
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

  Future<void> seedCategory({required String id, required String icon}) async {
    await db.into(db.categories).insert(CategoriesCompanion(
          id: Value(id),
          name: const Value('Food'),
          type: const Value('expense'),
          color: const Value('green'),
          icon: Value(icon),
          isArchived: const Value(false),
          updatedAt: Value(1),
          version: const Value(1),
        ));
  }

  testWidgets('creating a category persists the chosen icon', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Food');

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

    final rows = await db.select(db.categories).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Food');
    expect(rows.single.icon, 'cart');
  });

  testWidgets('editing loads the stored icon and saves it unchanged',
      (tester) async {
    await seedCategory(id: 'cat_food', icon: 'coins');
    await pumpForm(tester, categoryId: 'cat_food');

    expect(find.text('coins'), findsOneWidget);

    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final rows = await db.select(db.categories).get();
    expect(rows.single.icon, 'coins');
  });

  testWidgets('editing can change the icon', (tester) async {
    await seedCategory(id: 'cat_food', icon: 'coins');
    await pumpForm(tester, categoryId: 'cat_food');

    await tester.tap(find.text('Icon'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('icon-search-field')), 'gift');
    await tester.pumpAndSettle();

    final giftIcon = find.byIcon(FontAwesomeIcons.gift.data);
    expect(giftIcon, findsOneWidget);
    await tester.tap(giftIcon);
    await tester.pumpAndSettle();

    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final rows = await db.select(db.categories).get();
    expect(rows.single.icon, 'gift');
  });
}
