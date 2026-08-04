import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/categories_dao.dart';

void main() {
  group('AccountsDao', () {
    late AppDatabase db;
    late AccountsDao dao;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = AccountsDao(db);
      final now = DateTime(2026, 1, 15).millisecondsSinceEpoch;
      await dao.insertAccount(AccountsCompanion(
        id: const Value('acc_cash'),
        name: const Value('Cash'),
        type: const Value('cash'),
        currency: const Value('PHP'),
        color: const Value('teal'),
        icon: const Value('wallet'),
        isArchived: const Value(false),
        openingDate: Value(now),
        updatedAt: Value(now),
        version: const Value(1),
      ));
      addTearDown(db.close);
    });

    test('reopen clears the deleted_at tombstone', () async {
      await dao.archive('acc_cash', nowMillis: 1000);
      expect(await dao.active(), isEmpty);
      expect(await dao.watchArchived().first, hasLength(1));

      await dao.reopen('acc_cash', nowMillis: 2000);

      final account = await dao.byId('acc_cash');
      expect(account!.deletedAt, isNull);
      expect(account.updatedAt, 2000);
      expect(await dao.active(), hasLength(1));
      expect(await dao.watchArchived().first, isEmpty);
    });

    test('reopen is a no-op for an already active account', () async {
      await dao.reopen('acc_cash', nowMillis: 2000);
      expect(await dao.active(), hasLength(1));
      expect((await dao.byId('acc_cash'))!.deletedAt, isNull);
    });
  });

  group('CategoriesDao', () {
    late AppDatabase db;
    late CategoriesDao dao;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = CategoriesDao(db);
      final now = DateTime(2026, 1, 15).millisecondsSinceEpoch;
      await dao.insertCategory(CategoriesCompanion(
        id: const Value('cat_food'),
        name: const Value('Food'),
        type: const Value('expense'),
        color: const Value('orange'),
        icon: const Value('restaurant'),
        isArchived: const Value(false),
        updatedAt: Value(now),
        version: const Value(1),
      ));
      addTearDown(db.close);
    });

    test('reopen clears the deleted_at tombstone', () async {
      await dao.archive('cat_food', nowMillis: 1000);
      expect(await dao.watchArchived().first, hasLength(1));

      await dao.reopen('cat_food', nowMillis: 2000);

      final category = await dao.byId('cat_food');
      expect(category!.deletedAt, isNull);
      expect(await dao.watchArchived().first, isEmpty);
      expect(await dao.roots(), hasLength(1));
    });
  });
}
