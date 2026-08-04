import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The local SQLite database — the authoritative source of truth for Perako.
///
/// Firestore is only an additive sync/backup mirror; this database holds the
/// ledger and all balances are derived from it via the LedgerEngine.
@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    LedgerEntries,
    Tags,
    TransactionTags,
    SyncState,
    Profiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database, storing it as `perako.sqlite` in the app documents
  /// directory (Native SQLite on Android).
  AppDatabase()
      : super(
          driftDatabase(
            name: 'perako',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(profiles);
          }
        },
      );
}