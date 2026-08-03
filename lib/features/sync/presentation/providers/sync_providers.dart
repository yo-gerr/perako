import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/accounts_sync_table.dart';
import '../../data/device_id_store.dart';
import '../../data/firestore_sync_remote_store.dart';
import '../../domain/sync_engine.dart';

/// Per-install identity used to tag writes and ignore our own sync echoes.
/// Persisted outside the drift DB so it survives sign-out and DB wipes.
final deviceIdProvider = FutureProvider<String>((ref) {
  return const DeviceIdStore().loadOrCreate();
});

/// The Firestore-backed [SyncRemoteStore].
final syncRemoteStoreProvider = Provider((ref) {
  return FirestoreSyncRemoteStore(ref.watch(firestoreProvider));
});

/// The bidirectional [SyncEngine] wired to Firestore and the drift tables.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final store = ref.watch(syncRemoteStoreProvider);
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'device_default';
  return SyncEngine(
    db: db,
    store: store,
    deviceId: deviceId,
    tables: [AccountsSyncTable(db: db)],
  );
});

/// How the recent sync attempt went.
enum SyncStatus { idle, syncing, success, offline, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSyncAt,
  });

  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncAt;

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncAt,
    bool clearMessage = false,
    bool clearLastSync = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      lastSyncAt: clearLastSync ? null : (lastSyncAt ?? this.lastSyncAt),
    );
  }
}

/// Tracks the current sync state so the UI can render a status indicator.
final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);

class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  /// Runs a full sync (push local changes, then pull remote changes) for the
  /// signed-in user [uid]. No-op when there is no authenticated user.
  Future<void> syncNow(String uid) async {
    state = state.copyWith(status: SyncStatus.syncing);
    final engine = ref.read(syncEngineProvider);
    try {
      await engine.pushChanged(uid);
      await engine.pullAndApply(uid);
      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncAt: DateTime.now(),
        clearMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: e.toString(),
      );
    }
  }
}