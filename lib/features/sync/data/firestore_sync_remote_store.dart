import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/sync_remote_store.dart';

/// Production [SyncRemoteStore] backed by Firebase Firestore.
///
/// Documents are stored under `users/$uid/<collection>/<docId>` so each user's
/// data is isolated and Firestore rules can restrict access to
/// `request.auth.uid == uid`.
class FirestoreSyncRemoteStore implements SyncRemoteStore {
  FirestoreSyncRemoteStore(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<void> push(
    String uid,
    Map<String, Map<String, Map<String, Object?>>> docs, {
    bool advanceCursor = false,
  }) async {
    final userRef = firestore.collection('users').doc(uid);
    for (final entry in docs.entries) {
      final collection = entry.value;
      if (collection.isEmpty) continue;

      // Write per-collection; Firestore batches are limited, so one batch per
      // collection keeps it simple and within limits.
      final batch = firestore.batch();
      for (final doc in collection.entries) {
        final ref = userRef.collection(entry.key).doc(doc.key);
        batch.set(ref, doc.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  @override
  Future<List<RemoteSyncedDoc>> pullSince(
      String uid, String collection, int since) async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection(collection)
        .where('updatedAt', isGreaterThan: since)
        .get();
    return [
      for (final d in snap.docs)
        RemoteSyncedDoc(id: d.id, data: d.data().cast<String, Object?>()),
    ];
  }
}
