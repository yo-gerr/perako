import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Categories]. All SQL for categories is scoped here.
class CategoriesDao extends DatabaseAccessor<AppDatabase> {
  CategoriesDao(super.db);

  $CategoriesTable get categories => attachedDatabase.categories;

  Future<Category> insertCategory(CategoriesCompanion entry) async {
    return into(categories).insertReturning(entry);
  }

  Future<void> bulkInsertCategories(List<CategoriesCompanion> rows) =>
      batch((b) => b.insertAll(categories, rows));

  Future<int> updateCategory(CategoriesCompanion entry) async {
    return (update(categories)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Stream<List<Category>> watchActive() => (select(categories)
        ..where((t) => t.deletedAt.isNull()))
      .watch();

  Future<List<Category>> all() => select(categories).get();

  Future<Category?> byId(String id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Direct child categories of [parentId], excluding archived ones.
  Future<List<Category>> childrenOf(String parentId) => (select(categories)
        ..where(
            (t) => t.parentId.equals(parentId) & t.deletedAt.isNull()))
      .get();

  Future<List<Category>> roots() => (select(categories)
        ..where((t) => t.parentId.isNull() & t.deletedAt.isNull()))
      .get();

  Future<List<Category>> changedSince(int since) async {
    return (select(categories)
            ..where((t) => t.updatedAt.isBiggerOrEqualValue(since)))
        .get();
  }
}