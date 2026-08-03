import '../../../core/database/app_database.dart';
import '../../../core/database/daos/sync_state_dao.dart';
import 'sync_remote_store.dart';
import 'sync_table.dart';

/// The bidirectional sync engine.
///
/// SQLite (drift) remains the source of truth. Firestore is an additive mirror:
/// - [pushChanged] uploads local rows newer than the persisted cursor.
/// - [pullAndApply] fetches remote docs newer than the cursor and merges them.
/// - Conflicts resolve last-write-wins on `updatedAt`.
///
/// A per-device [deviceId] tag lets the dedup guard ignore our own echoes.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required this.store,
    required List<SyncTable> tables,
    required this.deviceId,
  })  : _tables = {for (final t in tables) t.collectionName: t},
        _cursorDao = SyncStateDao(db);

  final SyncRemoteStore store;
  final Map<String, SyncTable> _tables;
  final SyncStateDao _cursorDao;

  /// Per-device identity used to ignore our own sync echoes.
  final String deviceId;

  bool _isOwn(RemoteSyncedDoc doc) => doc.writer == deviceId;

  /// Uploads every table's local rows changed since its cursor, then advances
  /// each cursor. Returns the number of documents pushed.
  Future<int> pushChanged(String uid) async {
    int pushed = 0;
    for (final table in _tables.values) {
      final cursor = await _cursorDao.lastSyncedAt(table.collectionName);
      final rows = await table.changedSince(cursor);
      if (rows.isEmpty) continue;

      final docs = <String, Map<String, Object?>>{};
      for (final row in rows) {
        // Merge writer marker into the payload so pulls can dedup own echoes.
        docs[row.id] = {...row.payload, 'writer': deviceId};
        pushed++;
      }
      await store.push(uid, {table.collectionName: docs});

      final newCursor = table.maxStampFor(rows);
      await _cursorDao.setCursor(table.collectionName, newCursor);
    }
    return pushed;
  }

  /// Fetches remote docs newer than the cursor and applies them locally,
  /// resolving conflicts. Returns the number of documents applied.
  Future<int> pullAndApply(String uid) async {
    int applied = 0;
    for (final table in _tables.values) {
      final cursor = await _cursorDao.lastSyncedAt(table.collectionName);
      final remoteDocs =
          await store.pullSince(uid, table.collectionName, cursor);

      int maxRemote = cursor;
      for (final remote in remoteDocs) {
        if (_isOwn(remote)) continue; // dedup: ignore our own echo
        await _applyRemote(table, remote);
        applied++;
        if (remote.updatedAtMillis > maxRemote) {
          maxRemote = remote.updatedAtMillis;
        }
      }
      await _cursorDao.setCursor(table.collectionName, maxRemote);
    }
    return applied;
  }

  /// Applies a single remote document to a local table using last-write-wins.
  Future<void> _applyRemote(SyncTable table, RemoteSyncedDoc remote) async {
    final localUpdated = await table.readUpdatedAt(remote.id);
    if (localUpdated == null) {
      // No local row exists — apply (or tombstone-to-nothing) directly.
      await table.applyRemote(remote);
      return;
    }
    // Last-write-wins on updatedAt; if local is newer, it wins on the next push.
    if (remote.updatedAtMillis > localUpdated) {
      await table.applyRemote(remote);
    }
  }
}