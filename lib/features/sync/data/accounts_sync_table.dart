import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/accounts_dao.dart';
import '../domain/sync_remote_store.dart';
import '../domain/sync_table.dart';

/// Bridges the `accounts` drift table to the Firestore `accounts` collection.
class AccountsSyncTable implements SyncTable {
  AccountsSyncTable({required AppDatabase db})
      : _dao = AccountsDao(db);

  final AccountsDao _dao;

  @override
  String get collectionName => 'accounts';

  @override
  int maxStampFor(List<LocalRow> rows) {
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.updatedAtMillis).reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<List<LocalRow>> changedSince(int since) async {
    final rows = await _dao.changedSince(since);
    return [
      for (final a in rows)
        LocalRow(
          id: a.id,
          stamp: {
            'updatedAt': a.updatedAt,
            'deletedAt': a.deletedAt,
            'version': a.version,
          },
          payload: {
            'id': a.id,
            'name': a.name,
            'type': a.type,
            'currency': a.currency,
            'color': a.color,
            'icon': a.icon,
            'isArchived': a.isArchived,
            'openingDate': a.openingDate,
            'updatedAt': a.updatedAt,
            'deletedAt': a.deletedAt,
            'version': a.version,
          },
        ),
    ];
  }

  @override
  Future<void> applyRemote(RemoteSyncedDoc doc) async {
    final existing = await _dao.byId(doc.id);

    if (doc.isDeleted) {
      if (existing == null) return;
      await _dao.updateAccount(AccountsCompanion(
        id: Value(doc.id),
        updatedAt: Value(doc.updatedAtMillis),
        deletedAt: Value(doc.deletedAtMillis),
        version: Value(doc.version),
      ));
      return;
    }
    await _dao.upsert(AccountsCompanion(
      id: Value(doc.id),
      name: Value('${doc.data['name'] ?? ''}'),
      type: Value('${doc.data['type'] ?? ''}'),
      currency: Value('${doc.data['currency'] ?? 'PHP'}'),
      color: Value('${doc.data['color'] ?? ''}'),
      icon: Value('${doc.data['icon'] ?? ''}'),
      isArchived: Value(doc.data['isArchived'] == true),
      openingDate: Value((doc.data['openingDate'] as num?)?.toInt() ?? 0),
      updatedAt: Value(doc.updatedAtMillis),
      deletedAt: Value((doc.data['deletedAt'] as num?)?.toInt()),
      version: Value(doc.version),
    ));
  }

  @override
  Future<int?> readUpdatedAt(String id) async {
    final row = await _dao.byId(id);
    return row?.updatedAt;
  }
}