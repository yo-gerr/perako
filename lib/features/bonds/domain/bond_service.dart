import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/bonds_dao.dart';
import '../../ledger/domain/ledger_engine.dart';
import '../../transactions/domain/transaction_posting.dart';

/// How often a bond pays its coupon.
enum CouponSchedule {
  monthly('Monthly'),
  quarterly('Quarterly'),
  semiAnnual('Semi-annual'),
  annual('Annual');

  const CouponSchedule(this.label);

  final String label;

  int get intervalMonths => switch (this) {
        monthly => 1,
        quarterly => 3,
        semiAnnual => 6,
        annual => 12,
      };

  static CouponSchedule fromKey(String key) => CouponSchedule.values.firstWhere(
        (s) => s.name == key,
        orElse: () => CouponSchedule.annual,
      );
}

/// The bond engine: creates and edits fixed-income bonds, realizes coupons as
/// balanced income postings on schedule, flags matured bonds, and forecasts
/// the value at maturity.
///
/// The face value stays in the linked account for the whole term; every
/// coupon is computed on [Bonds.faceValueCents] and credited on its coupon
/// date. Coupon dates are anchored to [Bonds.startDate] at the schedule's
/// interval, so coupons are never credited twice and never drift off-grid.
class BondService {
  BondService({
    required this.db,
    required this.engine,
    required this.dao,
    String Function()? idGenerator,
    int Function()? clock,
  })  : _idGen = idGenerator ?? _defaultId,
        _clock = clock ?? _defaultClock;

  final AppDatabase db;
  final LedgerEngine engine;
  final BondsDao dao;

  final String Function() _idGen;
  final int Function() _clock;

  /// The coupon date at the zero-based [periodIndex] (0 = first coupon).
  static DateTime couponDateAt(
    DateTime start,
    CouponSchedule schedule,
    int periodIndex,
  ) =>
      _addMonths(start, schedule.intervalMonths * periodIndex);

  /// The first coupon date of a bond starting at [start].
  static DateTime firstCouponDate(DateTime start, CouponSchedule schedule) =>
      couponDateAt(start, schedule, 1);

  /// Every coupon date from [start] at [schedule] intervals up to and
  /// including [maturity].
  static List<DateTime> couponDates(
    DateTime start,
    CouponSchedule schedule,
    DateTime maturity,
  ) {
    final dates = <DateTime>[];
    var index = 1;
    while (true) {
      final date = couponDateAt(start, schedule, index);
      if (date.isAfter(maturity)) break;
      dates.add(date);
      index++;
    }
    return dates;
  }

  /// The first coupon date of a bond starting at [start] strictly after
  /// [after], used to seed [Bonds.nextCouponDate].
  static DateTime firstCouponDateAfter(
    DateTime start,
    CouponSchedule schedule,
    DateTime after,
  ) {
    var index = 1;
    var date = couponDateAt(start, schedule, index);
    while (!date.isAfter(after)) {
      index++;
      date = couponDateAt(start, schedule, index);
    }
    return date;
  }

  /// The coupon paid each period in integer cents: the annual coupon rate
  /// prorated over the schedule interval and applied to the face value.
  static int couponAmount({
    required int faceValueCents,
    required double couponRate,
    required CouponSchedule schedule,
  }) {
    if (couponRate <= 0) return 0;
    return (faceValueCents * couponRate * schedule.intervalMonths / 12)
        .round();
  }

  /// Creates a bond with a fixed term from [startDate] to [maturityDate].
  /// Nothing moves through the ledger until the first coupon is realized.
  Future<Bond> create({
    required String accountId,
    required String label,
    required int faceValueCents,
    required double couponRate,
    required CouponSchedule schedule,
    required DateTime startDate,
    required DateTime maturityDate,
  }) async {
    final now = _clock();
    return dao.insert(BondsCompanion(
      id: Value(_idGen()),
      accountId: Value(accountId),
      label: Value(label),
      faceValueCents: Value(faceValueCents),
      couponRate: Value(couponRate),
      couponSchedule: Value(schedule.name),
      startDate: Value(startDate.millisecondsSinceEpoch),
      maturityDate: Value(maturityDate.millisecondsSinceEpoch),
      nextCouponDate: Value(
        firstCouponDateAfter(startDate, schedule, startDate)
            .millisecondsSinceEpoch,
      ),
      isMatured: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
      version: const Value(1),
    ));
  }

  /// Updates an unmatured bond, re-seeding the coupon cursor past the last
  /// realized coupon so already-credited coupons are never replayed.
  Future<void> update(
    Bond bond, {
    required String label,
    required int faceValueCents,
    required double couponRate,
    required CouponSchedule schedule,
    required DateTime startDate,
    required DateTime maturityDate,
  }) async {
    final coupons = await dao.couponsFor(bond.id);
    final anchor = coupons.isEmpty
        ? startDate
        : DateTime.fromMillisecondsSinceEpoch(
            coupons.map((c) => c.paidOn).reduce((a, b) => a > b ? a : b),
          );
    await dao.updateEntry(BondsCompanion(
      id: Value(bond.id),
      label: Value(label),
      faceValueCents: Value(faceValueCents),
      couponRate: Value(couponRate),
      couponSchedule: Value(schedule.name),
      startDate: Value(startDate.millisecondsSinceEpoch),
      maturityDate: Value(maturityDate.millisecondsSinceEpoch),
      nextCouponDate: Value(
        firstCouponDateAfter(startDate, schedule, anchor)
            .millisecondsSinceEpoch,
      ),
      updatedAt: Value(_clock()),
    ));
  }

  /// Realizes every coupon that has reached [now] (defaults to the current
  /// time): posts the coupon as an income transaction dated on its coupon date
  /// and records a [BondCoupons] row so it is never credited twice. Coupons
  /// past the term are never credited. Returns the number of coupons posted.
  Future<int> processCoupons({DateTime? now}) async {
    final asOf = _dateOnly(now ?? DateTime.now());
    final bonds = await dao.active();
    var processed = 0;
    for (final bond in bonds) {
      final schedule = CouponSchedule.fromKey(bond.couponSchedule);
      final start = _dateOnly(DateTime.fromMillisecondsSinceEpoch(bond.startDate));
      final maturity =
          _dateOnly(DateTime.fromMillisecondsSinceEpoch(bond.maturityDate));
      final dates = couponDates(start, schedule, maturity);
      final realized = {
        for (final c in await dao.couponsFor(bond.id))
          _dateOnly(DateTime.fromMillisecondsSinceEpoch(c.paidOn))
              .millisecondsSinceEpoch,
      };

      for (var i = 0; i < dates.length; i++) {
        final date = dates[i];
        if (date.isAfter(asOf)) break;
        if (realized.contains(date.millisecondsSinceEpoch)) continue;

        final coupon = couponAmount(
          faceValueCents: bond.faceValueCents,
          couponRate: bond.couponRate,
          schedule: schedule,
        );
        String? transactionId;
        if (coupon > 0) {
          transactionId = await engine.postTransaction(
            description: 'Bond coupon ${i + 1} — ${bond.label}',
            on: date,
            lines: buildLedgerLines(
              type: TxType.income,
              accountId: bond.accountId,
              amountCents: coupon,
            ),
          );
        }
        await dao.insertCoupon(BondCouponsCompanion(
          id: Value(_idGen()),
          bondId: Value(bond.id),
          transactionId: Value(transactionId),
          period: Value(i),
          couponCents: Value(coupon),
          paidOn: Value(date.millisecondsSinceEpoch),
          createdAt: Value(_clock()),
        ));
        processed++;
      }

      // Advance the cursor to the first unpaid coupon date.
      final nextUnpaid = dates.firstWhere(
        (d) => d.isAfter(asOf),
        orElse: () => couponDateAt(start, schedule, dates.length + 1),
      );
      await dao.updateEntry(BondsCompanion(
        id: Value(bond.id),
        nextCouponDate: Value(nextUnpaid.millisecondsSinceEpoch),
        updatedAt: Value(_clock()),
      ));
    }
    return processed;
  }

  /// Marks every bond whose term has ended as matured. Returns the number
  /// newly matured.
  Future<int> processMaturities({DateTime? now}) async {
    final asOf = _dateOnly(now ?? DateTime.now());
    final bonds = await dao.active();
    var processed = 0;
    for (final bond in bonds) {
      final maturity =
          _dateOnly(DateTime.fromMillisecondsSinceEpoch(bond.maturityDate));
      if (!bond.isMatured && !maturity.isAfter(asOf)) {
        await dao.updateEntry(BondsCompanion(
          id: Value(bond.id),
          isMatured: const Value(true),
          updatedAt: Value(_clock()),
        ));
        processed++;
      }
    }
    return processed;
  }

  /// The coupons still to be paid after [now] (defaults to the current time),
  /// oldest first.
  Future<List<DateTime>> remainingCouponDates(Bond bond, {DateTime? now}) async {
    final asOf = _dateOnly(now ?? DateTime.now());
    final start = _dateOnly(DateTime.fromMillisecondsSinceEpoch(bond.startDate));
    final maturity =
        _dateOnly(DateTime.fromMillisecondsSinceEpoch(bond.maturityDate));
    final schedule = CouponSchedule.fromKey(bond.couponSchedule);
    return couponDates(start, schedule, maturity)
        .where((d) => d.isAfter(asOf))
        .toList();
  }

  /// Projected interest still to be received: each unpaid coupon amount.
  Future<int> forecastCouponCents(Bond bond, {DateTime? now}) async {
    final remaining = await remainingCouponDates(bond, now: now);
    return remaining.length *
        couponAmount(
          faceValueCents: bond.faceValueCents,
          couponRate: bond.couponRate,
          schedule: CouponSchedule.fromKey(bond.couponSchedule),
        );
  }

  /// Projected value at maturity: the current ledger balance plus every
  /// coupon still to be paid.
  Future<int> forecastMaturityValue(Bond bond, {DateTime? now}) async {
    final balance = await engine.getBalance(bond.accountId);
    return balance + await forecastCouponCents(bond, now: now);
  }

  static DateTime _addMonths(DateTime date, int months) {
    final total = date.year * 12 + (date.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _counter = 0;

  static String _defaultId() =>
      'bond_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;
}
