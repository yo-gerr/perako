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
    Budgets,
    CategoryBudgetLimits,
    Bills,
    BillPayments,
    Goals,
    GoalContributions,
    SavingsAccounts,
    InterestSchedules,
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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(profiles);
          }
          if (from < 3) {
            await m.createTable(budgets);
            await m.createTable(categoryBudgetLimits);
          }
          if (from < 4) {
            await m.createTable(bills);
            await m.createTable(billPayments);
          }
          if (from < 5) {
            await m.createTable(goals);
            await m.createTable(goalContributions);
          }
          if (from < 6) {
            await m.createTable(savingsAccounts);
            await m.createTable(interestSchedules);
          }
        },
      );
}