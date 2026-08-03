import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/features/sync/data/accounts_sync_table.dart';
import 'package:perako/features/sync/domain/sync_engine.dart';

import '../../helpers/fake_sync_remote_store.dart';

void main() {
  late AppDatabase db;
  late FakeSyncRemoteStore store;
  late SyncEngine engine;
  late int clock;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = FakeSyncRemoteStore();
    clock = 1_000_000;
    engine = SyncEngine(
      db: db,
      store: store,
      deviceId: 'device_a',
      tables: [AccountsSyncTable(db: db)],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedLocalAccount(String id,
      {String name = 'Checking', int? updatedAt}) async {
    final t = updatedAt ?? clock;
    await db.into(db.accounts).insert(AccountsCompanion(
          id: Value(id),
          name: Value(name),
          type: const Value('checking'),
          currency: const Value('PHP'),
          color: const Value('teal'),
          icon: const Value('wallet'),
          isArchived: const Value(false),
          openingDate: Value(0),
          updatedAt: Value(t),
          version: const Value(1),
        ));
  }

  test('pushChanged uploads local dirty rows and advances cursor', () async {
    await seedLocalAccount('acc1', updatedAt: 100);
    await seedLocalAccount('acc2', updatedAt: 200);

    final pushed = await engine.pushChanged('userA');
    expect(pushed, 2);

    // Store now holds both docs tagged with our device id.
    expect(store.store['userA']!['accounts']!['acc1'], isNotNull);
    expect(store.store['userA']!['accounts']!['acc1']!['writer'], 'device_a');
    expect(store.store['userA']!['accounts']!['acc2'], isNotNull);

    // A second push is a no-op: nothing changed since the cursor.
    clock = 300;
    final pushedAgain = await engine.pushChanged('userA');
    expect(pushedAgain, 0);
  });

  test('pullAndApply inserts remote docs not present locally', () async {
    await store.push('userA', {
      'accounts': {
        'remote1': accountDoc(
            id: 'remote1', name: 'Shares', updatedAt: 500),
      },
    });

    final applied = await engine.pullAndApply('userA');
    expect(applied, 1);

    final row = await db.select(db.accounts).getSingleOrNull();
    expect(row?.id, 'remote1');
    expect(row?.name, 'Shares');
  });

  test('conflict resolution is last-write-wins on updatedAt', () async {
    // Local account is newer (600) than remote (400).
    await seedLocalAccount('acc1', updatedAt: 600);
    final before = (await db.select(db.accounts).getSingle());
    expect(before.updatedAt, 600);

    await store.push('userA', {
      'accounts': {
        'acc1': accountDoc(id: 'acc1', name: 'RemoteOlder', updatedAt: 400),
      },
    });
    await engine.pullAndApply('userA');

    // Local newer -> local wins, name unchanged.
    var row = (await db.select(db.accounts).getSingle());
    expect(row.name, 'Checking');

    // Now remote is newer (800) -> remote wins.
    await store.push('userA', {
      'accounts': {
        'acc1': accountDoc(id: 'acc1', name: 'RemoteNewer', updatedAt: 800),
      },
    });
    await engine.pullAndApply('userA');
    row = (await db.select(db.accounts).getSingle());
    expect(row.updatedAt, 800);
    expect(row.name, 'RemoteNewer');
  });

  test('dedup ignores documents authored by this device', () async {
    // Simulate our own echo coming back from the store.
    await store.push('userA', {
      'accounts': {
        'accEcho': accountDoc(
            id: 'accEcho', name: 'Echo', updatedAt: 700, writer: 'device_a'),
      },
    });
    final applied = await engine.pullAndApply('userA');
    // Skipped because writer == our device id.
    expect(applied, 0);
  });

  test('tombstoned remote docs soft-delete local rows', () async {
    await seedLocalAccount('acc1', updatedAt: 100);
    await store.push('userA', {
      'accounts': {
        'acc1': accountDoc(
            id: 'acc1',
            name: 'Checking',
            updatedAt: 900,
            deletedAt: 900),
      },
    });
    await engine.pullAndApply('userA');

    final row = await db.select(db.accounts).getSingleOrNull();
    // Row still exists locally but carries a deletedAt stamp (soft delete).
    expect(row, isNotNull);
    expect(row!.deletedAt, isNotNull);
  });

  test('data is namespaced per user; another user is not visible', () async {
    // A different user's account exists in the store under userB.
    await store.push('userB', {
      'accounts': {
        'other': accountDoc(
            id: 'other', name: 'OtherUser', updatedAt: 500),
      },
    });

    // Pulling as userA sees nothing from userB's namespace.
    final pulled = await store.pullSince('userA', 'accounts', 0);
    expect(pulled, isEmpty);
    expect(store.store['userA'], isNull);
  });
}
