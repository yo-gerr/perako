import 'package:perako/features/sync/domain/sync_remote_store.dart';

/// In-memory [SyncRemoteStore] backed by uid -> collection -> id -> data.
///
/// Mimics Firestore's user-scoped `push` and `pullSince` semantics so the
/// [SyncEngine] can be tested without a network.
class FakeSyncRemoteStore implements SyncRemoteStore {
  final _db = <String, Map<String, Map<String, Map<String, Object?>>>>{};

  /// Public read access for test assertions (uid -> collection -> doc id).
  Map<String, Map<String, Map<String, Map<String, Object?>>>>
      get store => _db;

  @override
  Future<void> push(
    String uid,
    Map<String, Map<String, Map<String, Object?>>> docs, {
    bool advanceCursor = false,
  }) async {
    final user = _db.putIfAbsent(uid, () => {});
    for (final entry in docs.entries) {
      final collection = user.putIfAbsent(entry.key, () => {});
      for (final doc in entry.value.entries) {
        collection[doc.key] = {...doc.value};
      }
    }
  }

  @override
  Future<List<RemoteSyncedDoc>> pullSince(
      String uid, String collection, int since) async {
    final all = _db[uid]?[collection] ?? const {};
    final out = <RemoteSyncedDoc>[];
    for (final entry in all.entries) {
      final updated = (entry.value['updatedAt'] as num?)?.toInt() ?? 0;
      if (updated > since) {
        out.add(RemoteSyncedDoc(id: entry.key, data: entry.value));
      }
    }
    return out;
  }
}

/// Builds a stamp map matching what the production engine writes for rows.
Map<String, Object?> accountDoc({
  required String id,
  required String name,
  required int updatedAt,
  int? deletedAt,
  int version = 1,
  String? writer,
  String type = 'checking',
  String currency = 'PHP',
  String color = 'teal',
  String icon = 'wallet',
  bool isArchived = false,
  int openingDate = 0,
}) {
  return {
    'id': id,
    'name': name,
    'type': type,
    'currency': currency,
    'color': color,
    'icon': icon,
    'isArchived': isArchived,
    'openingDate': openingDate,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
    'version': version,
    'writer': ?writer,
  };
}