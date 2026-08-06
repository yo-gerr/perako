import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/bill_service.dart';

/// The bill engine, backed by the ledger.
final billServiceProvider = Provider<BillService>((ref) {
  return BillService(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(ledgerEngineProvider),
    billsDao: ref.watch(billsDaoProvider),
  );
});

/// Materializes due bills into ledger expenses. Runs once per app session (the
/// future is cached), so the app boot hook and the bills screen can both await
/// it safely. Idempotent: already-due bills are paid exactly once.
final billCatchUpProvider = FutureProvider<int>((ref) {
  return ref.watch(billServiceProvider).catchUpDueBills();
});

/// All active (non-archived) bills.
final billsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(billsDaoProvider).watchActive();
});

/// Archived (soft-deleted) bills.
final archivedBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(billsDaoProvider).watchArchived();
});

/// A single bill by id, or null.
final billProvider = FutureProvider.family<Bill?, String>((ref, id) {
  return ref.watch(billsDaoProvider).byId(id);
});

/// Payment history for a bill, newest first.
final billPaymentsProvider = StreamProvider.family<List<BillPayment>, String>(
  (ref, billId) {
    return ref
        .watch(billsDaoProvider)
        .watchPaymentsFor(billId)
        .map((rows) {
          final sorted = [...rows];
          sorted.sort((a, b) => b.paidOn.compareTo(a.paidOn));
          return sorted;
        });
  },
);

/// A bill paired with its payment history, for the detail screen.
class BillDetailData {
  const BillDetailData({required this.bill, required this.payments});

  final Bill bill;
  final List<BillPayment> payments;
}

final billDetailProvider =
    StreamProvider.family<BillDetailData?, String>((ref, id) async* {
  final dao = ref.watch(billsDaoProvider);
  await for (final _ in dao.watchActive()) {
    final bill = await dao.byId(id);
    if (bill == null) {
      yield null;
      continue;
    }
    final payments = await dao.paymentsFor(id);
    payments.sort((a, b) => b.paidOn.compareTo(a.paidOn));
    yield BillDetailData(bill: bill, payments: payments);
  }
});
