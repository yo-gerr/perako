import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/profiles_dao.dart';

void main() {
  late AppDatabase db;
  late ProfilesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ProfilesDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  ProfilesCompanion profile(String uid, String name, {int updatedAt = 1}) {
    return ProfilesCompanion(
      uid: Value(uid),
      displayName: Value(name),
      currency: const Value('PHP'),
      createdAt: Value(1),
      updatedAt: Value(updatedAt),
    );
  }

  test('upsert inserts a new profile', () async {
    await dao.upsert(profile('u1', 'Rey'));
    final row = await dao.byUid('u1');
    expect(row, isNotNull);
    expect(row!.displayName, 'Rey');
    expect(row.currency, 'PHP');
  });

  test('upsert updates an existing profile', () async {
    await dao.upsert(profile('u1', 'Rey', updatedAt: 1));
    await dao.upsert(profile('u1', 'Rogelio', updatedAt: 2));

    final row = await dao.byUid('u1');
    expect(row!.displayName, 'Rogelio');
    expect(row.updatedAt, 2);
  });

  test('byUid returns null for unknown uids', () async {
    expect(await dao.byUid('missing'), isNull);
  });
}
