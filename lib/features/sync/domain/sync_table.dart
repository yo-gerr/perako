import 'sync_remote_store.dart';

/// A local row that the sync engine understands, regardless of which table it
/// lives in. [stamp] carries the sync metadata fields.
class LocalRow {
  const LocalRow({required this.id, required this.stamp, required this.payload});

  final String id;
  final Map<String, Object?> stamp;

  /// The full column map (including stamp fields) needed to write to Firestore.
  final Map<String, Object?> payload;

  int get updatedAtMillis => (stamp['updatedAt'] as num?)?.toInt() ?? 0;
  int get deletedAtMillis => (stamp['deletedAt'] as num?)?.toInt() ?? 0;
  bool get isDeleted => deletedAtMillis != 0;
  int get version => (stamp['version'] as num?)?.toInt() ?? 0;
}

/// Bridges one drift table to its Firestore collection for sync.
///
/// Implementations convert drift data classes to/from the generic [LocalRow]
/// / [RemoteDoc] forms used by the [SyncEngine].
abstract class SyncTable {
  /// Firestore collection name for this table.
  String get collectionName;

  /// Local rows whose `updatedAt >= since` (the push dirty set).
  Future<List<LocalRow>> changedSince(int since);

  /// Apply a remote document locally: upsert if not deleted, else tombstone.
  Future<void> applyRemote(RemoteSyncedDoc doc);

  /// The local `updatedAt` stamp for row [id], or null if it does not exist.
  /// Powers last-write-wins conflict resolution.
  Future<int?> readUpdatedAt(String id);

  /// The local `updatedAt` stamp value for rows read from this table, used to
  /// advance the cursor. Returns the max stamp among the pushed rows.
  int maxStampFor(List<LocalRow> rows) {
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.updatedAtMillis).reduce((a, b) => a > b ? a : b);
  }
}