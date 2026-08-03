/// Abstraction over the Firebase Firestore operations the sync engine needs.
///
/// The production implementation wraps [FirebaseFirestore]; tests substitute an
/// in-memory fake so sync logic can be exercised without a network.
///
/// All operations are scoped to a signed-in user ([uid]) and resolve paths that
/// look like `users/$uid/accounts/...`. This keeps each user's data isolated so
/// Firestore security rules can grant `request.auth.uid` access only to their
/// own subtree.
abstract class SyncRemoteStore {
  /// Uploads [docs] (collection name -> doc id -> data) for [uid].
  /// `advanceCursor` is reserved for future atomic cursor updates.
  Future<void> push(
    String uid,
    Map<String, Map<String, Map<String, Object?>>> docs, {
    bool advanceCursor = false,
  });

  /// Returns remote docs for [uid]/[collection] whose `updatedAt > since`.
  Future<List<RemoteSyncedDoc>> pullSince(String uid, String collection,
      int since);
}

/// A remote document returned by [SyncRemoteStore.pullSince].
class RemoteSyncedDoc {
  const RemoteSyncedDoc({required this.id, required this.data});

  final String id;
  final Map<String, Object?> data;

  int get updatedAtMillis => (data['updatedAt'] as num?)?.toInt() ?? 0;
  int get deletedAtMillis => (data['deletedAt'] as num?)?.toInt() ?? 0;
  bool get isDeleted => deletedAtMillis != 0;
  int get version => (data['version'] as num?)?.toInt() ?? 0;
  String? get writer => data['writer'] as String?;
}