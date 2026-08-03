import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';

void main() {
  test('in-memory database opens and creates schema', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Verify the schema was created by running a simple select against a table.
    final accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
  });
}