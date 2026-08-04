import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/accounts_dao.dart';
import '../../core/database/daos/categories_dao.dart';
import '../../core/database/daos/database_wipe_service.dart';
import '../../core/database/daos/ledger_dao.dart';
import '../../core/database/daos/profiles_dao.dart';
import '../../core/database/daos/transactions_dao.dart';
import '../../features/ledger/domain/ledger_engine.dart';

/// The drift-backed [AppDatabase] — the single source of truth.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The ledger engine — double-entry posting and balance derivation.
final ledgerEngineProvider = Provider<LedgerEngine>((ref) {
  return LedgerEngine(db: ref.watch(appDatabaseProvider));
});

/// Non-reactive access to accounts persistence.
final accountsDaoProvider = Provider<AccountsDao>((ref) {
  return AccountsDao(ref.watch(appDatabaseProvider));
});

/// Non-reactive access to categories persistence.
final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  return CategoriesDao(ref.watch(appDatabaseProvider));
});

/// Non-reactive access to transactions persistence.
final transactionsDaoProvider = Provider<TransactionsDao>((ref) {
  return TransactionsDao(ref.watch(appDatabaseProvider));
});

/// Non-reactive access to ledger entries.
final ledgerDaoProvider = Provider<LedgerDao>((ref) {
  return LedgerDao(ref.watch(appDatabaseProvider));
});

/// Non-reactive access to profiles persistence.
final profilesDaoProvider = Provider<ProfilesDao>((ref) {
  return ProfilesDao(ref.watch(appDatabaseProvider));
});

/// The Firestore instance used by the sync layer. Overridable in tests by a
/// fake so sync logic runs without a network dependency.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// The [FirebaseAuth] instance used by the auth layer.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Clears all local ledger data + sync cursors (used on sign-out/user switch).
final databaseWipeServiceProvider = Provider<DatabaseWipeService>((ref) {
  return DatabaseWipeService(ref.watch(appDatabaseProvider));
});