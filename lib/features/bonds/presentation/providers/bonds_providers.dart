import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/bond_service.dart';

/// The bond engine, backed by the ledger.
final bondServiceProvider = Provider<BondService>((ref) {
  return BondService(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(ledgerEngineProvider),
    dao: ref.watch(bondsDaoProvider),
  );
});

/// A bond paired with its account, ready for the list screen.
class BondRow {
  const BondRow({required this.bond, required this.account});

  final Bond bond;
  final Account account;

  bool get isMatured => bond.isMatured;

  /// Whole days until maturity; <= 0 once the term has ended.
  int daysLeft(DateTime now) =>
      _dateOnly(DateTime.fromMillisecondsSinceEpoch(bond.maturityDate))
          .difference(_dateOnly(now))
          .inDays;

  /// True once the term has ended but the bond is not yet flagged matured.
  bool isDue(DateTime now) => !isMatured && daysLeft(now) <= 0;

  /// The next coupon date to be credited, or null once all coupons are paid.
  DateTime? nextCouponDate(DateTime now) {
    final date = DateTime.fromMillisecondsSinceEpoch(bond.nextCouponDate);
    final maturity = DateTime.fromMillisecondsSinceEpoch(bond.maturityDate);
    if (date.isAfter(maturity)) return null;
    return date;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// All active bonds paired with their accounts, newest creation first. Emits
/// a fresh snapshot on any bond, account, or ledger change.
final bondsProvider = StreamProvider<List<BondRow>>((ref) async* {
  final dao = ref.watch(bondsDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final bonds = await dao.active();
    final allAccounts = await accountsDao.active();
    final rows = <BondRow>[];
    for (final bond in bonds) {
      final account =
          allAccounts.where((a) => a.id == bond.accountId).toList();
      if (account.isEmpty) continue;
      rows.add(BondRow(bond: bond, account: account.first));
    }
    rows.sort((a, b) => b.bond.createdAt.compareTo(a.bond.createdAt));
    yield rows;
  }
});

/// Archived bonds paired with their accounts.
final archivedBondsProvider = StreamProvider<List<BondRow>>((ref) async* {
  final dao = ref.watch(bondsDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchArchived(),
    accountsDao.watchActive(),
  ]);

  await for (final _ in trigger) {
    final bonds = await dao.archived();
    final allAccounts = await accountsDao.active();
    final rows = <BondRow>[];
    for (final bond in bonds) {
      final account =
          allAccounts.where((a) => a.id == bond.accountId).toList();
      if (account.isEmpty) continue;
      rows.add(BondRow(bond: bond, account: account.first));
    }
    rows.sort((a, b) => b.bond.createdAt.compareTo(a.bond.createdAt));
    yield rows;
  }
});

/// Everything the detail screen renders for one bond.
class BondDetailData {
  const BondDetailData({
    required this.row,
    required this.balanceCents,
    required this.maturityValueCents,
    required this.forecastCouponCents,
    required this.nextCouponDate,
    required this.remainingCouponDates,
  });

  final BondRow row;
  final int balanceCents;

  /// Projected balance at maturity: balance plus unpaid coupons.
  final int maturityValueCents;

  /// Total interest still to be received.
  final int forecastCouponCents;

  /// The next coupon date to credit, or null when all coupons are paid.
  final DateTime? nextCouponDate;

  /// The unpaid coupon dates, oldest first.
  final List<DateTime> remainingCouponDates;

  Bond get bond => row.bond;
  Account get account => row.account;
}

/// Full detail snapshot for one bond, recomputed on any bond, coupon,
/// account, or ledger change.
final bondDetailProvider =
    StreamProvider.family<BondDetailData?, String>((ref, id) async* {
  final dao = ref.watch(bondsDaoProvider);
  final accountsDao = ref.watch(accountsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final service = ref.watch(bondServiceProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    dao.watchCouponsFor(id),
    accountsDao.watchActive(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final bond = await dao.byId(id);
    if (bond == null || bond.deletedAt != null) {
      yield null;
      continue;
    }
    final account = await accountsDao.byId(bond.accountId);
    if (account == null) {
      yield null;
      continue;
    }
    final balance = await service.engine.getBalance(bond.accountId);
    final remaining = await service.remainingCouponDates(bond);
    final forecastCoupons = await service.forecastCouponCents(bond);
    final maturityValue = await service.forecastMaturityValue(bond);
    yield BondDetailData(
      row: BondRow(bond: bond, account: account),
      balanceCents: balance,
      maturityValueCents: maturityValue,
      forecastCouponCents: forecastCoupons,
      nextCouponDate: BondRow(bond: bond, account: account).nextCouponDate(DateTime.now()),
      remainingCouponDates: remaining,
    );
  }
});

/// Realized coupon rows for one bond, oldest first.
final bondCouponsProvider =
    StreamProvider.family<List<BondCoupon>, String>((ref, id) {
  return ref.watch(bondsDaoProvider).watchCouponsFor(id);
});

/// Display label helper shared by the bond screens.
String bondTitle(BondRow row) {
  final label = row.bond.label.trim();
  if (label.isNotEmpty) return label;
  return row.account.name;
}
