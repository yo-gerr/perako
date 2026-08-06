import 'package:drift/drift.dart';

import '../app_database.dart';

/// Persistence for [Bonds] and [BondCoupons]. All SQL for bonds is scoped
/// here.
class BondsDao extends DatabaseAccessor<AppDatabase> {
  BondsDao(super.db);

  $BondsTable get bonds => attachedDatabase.bonds;

  $BondCouponsTable get bondCoupons => attachedDatabase.bondCoupons;

  Future<Bond> insert(BondsCompanion entry) async {
    return into(bonds).insertReturning(entry);
  }

  Future<int> updateEntry(BondsCompanion entry) async {
    return (update(bonds)..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<int> archive(String id, {required int nowMillis}) {
    return (update(bonds)..where((t) => t.id.equals(id))).write(
      BondsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: Value(nowMillis),
      ),
    );
  }

  Future<int> reopen(String id, {required int nowMillis}) {
    return (update(bonds)..where((t) => t.id.equals(id))).write(
      BondsCompanion(
        updatedAt: Value(nowMillis),
        deletedAt: const Value(null),
      ),
    );
  }

  Stream<List<Bond>> watchActive() =>
      (select(bonds)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<Bond>> active() =>
      (select(bonds)..where((t) => t.deletedAt.isNull())).get();

  Stream<List<Bond>> watchArchived() =>
      (select(bonds)..where((t) => t.deletedAt.isNotNull())).watch();

  Future<List<Bond>> archived() =>
      (select(bonds)..where((t) => t.deletedAt.isNotNull())).get();

  Future<Bond?> byId(String id) =>
      (select(bonds)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<BondCoupon>> couponsFor(String bondId) =>
      (select(bondCoupons)..where((t) => t.bondId.equals(bondId))).get();

  Stream<List<BondCoupon>> watchCouponsFor(String bondId) =>
      (select(bondCoupons)..where((t) => t.bondId.equals(bondId))).watch();

  Future<void> insertCoupon(BondCouponsCompanion entry) async {
    await into(bondCoupons).insert(entry);
  }
}
