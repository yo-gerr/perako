import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persists the last-synced cursor for each collection.
class SyncStateDao extends DatabaseAccessor<AppDatabase> {
  SyncStateDao(super.db);

  $SyncStateTable get syncState => attachedDatabase.syncState;

  Future<int> lastSyncedAt(String collection) async {
    final row = await (select(syncState)
          ..where((t) => t.collection.equals(collection)))
        .getSingleOrNull();
    return row?.lastSyncedAt ?? 0;
  }

  Future<void> setCursor(String collection, int lastSyncedAt) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion.insert(
        collection: collection,
        lastSyncedAt: Value(lastSyncedAt),
      ),
    );
  }
}