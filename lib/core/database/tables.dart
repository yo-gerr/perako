import 'package:drift/drift.dart';

class Accounts extends Table {
  /// Stable shared id (UUID). Also used as the Firestore document id.
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Account type, e.g. cash, wallet, checking, savings, investment, credit_card, loan.
  TextColumn get type => text()();

  TextColumn get currency => text()();

  TextColumn get color => text()();

  TextColumn get icon => text()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get openingDate => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get parentId => text().nullable()();

  // income | expense | transfer
  TextColumn get type => text()();

  TextColumn get color => text()();

  TextColumn get icon => text()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();

  TextColumn get description => text()();

  IntColumn get date => integer()();

  TextColumn get notes => text().nullable()();

  TextColumn get receiptPath => text().nullable()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LedgerEntries extends Table {
  TextColumn get id => text()();

  TextColumn get transactionId => text().references(Transactions, #id)();

  TextColumn get accountId => text().references(Accounts, #id)();

  TextColumn get categoryId => text().references(Categories, #id).nullable()();

  // Amount in integer cents. Always positive; direction is encoded by [type].
  IntColumn get amount => integer()();

  // debit | credit
  TextColumn get type => text()();

  IntColumn get entryDate => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get color => text()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TransactionTags extends Table {
  TextColumn get transactionId => text().references(Transactions, #id)();

  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, tagId};
}

/// Persists per-collection sync cursors (surrogate key = collection name).
///
/// The cursor is the highest `updatedAt` already processed for a given
/// collection, so pushes and pulls can be incremental.
class SyncState extends Table {
  TextColumn get collection => text()();

  IntColumn get lastSyncedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}