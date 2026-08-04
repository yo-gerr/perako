import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Profiles]. All SQL for profiles is scoped here.
class ProfilesDao extends DatabaseAccessor<AppDatabase> {
  ProfilesDao(super.db);

  $ProfilesTable get profiles => attachedDatabase.profiles;

  Future<Profile?> byUid(String uid) =>
      (select(profiles)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  /// Inserts or updates the profile row for [entry.uid].
  Future<void> upsert(ProfilesCompanion entry) async {
    final existing = await byUid(entry.uid.value);
    if (existing == null) {
      await into(profiles).insert(entry);
    } else {
      await (update(profiles)..where((t) => t.uid.equals(entry.uid.value)))
          .write(entry);
    }
  }
}
