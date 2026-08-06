import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../domain/report_service.dart';

/// The range + bucket resolution shared by every report screen.
class ReportRange {
  const ReportRange({
    required this.from,
    required this.to,
    required this.resolution,
  });

  final DateTime from;
  final DateTime to;
  final ReportResolution resolution;
}

class ReportRangeNotifier extends Notifier<ReportRange> {
  @override
  ReportRange build() {
    final now = DateTime.now();
    return _for(
      DateTime(now.year, now.month - 3, now.day),
      now,
    );
  }

  ReportRange _for(DateTime from, DateTime to) =>
      ReportRange(from: from, to: to, resolution: resolveForRange(from, to));

  void setRange(DateTime from, DateTime to) {
    state = _for(from, to);
  }
}

/// The active report window (defaults to the last three months).
final reportsRangeProvider =
    NotifierProvider<ReportRangeNotifier, ReportRange>(
  ReportRangeNotifier.new,
);

/// The report engine, backed by the ledger.
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(
    ledgerDao: ref.watch(ledgerDaoProvider),
    accountsDao: ref.watch(accountsDaoProvider),
  );
});

/// Net worth as of the end of each bucket in the active range.
final netWorthReportProvider = FutureProvider<List<NetWorthPoint>>((ref) async {
  final range = ref.watch(reportsRangeProvider);
  final service = ref.watch(reportServiceProvider);
  return service.netWorthSeries(
    from: range.from,
    to: range.to,
    resolution: range.resolution,
  );
});

/// Income and expense per bucket in the active range.
final cashFlowReportProvider = FutureProvider<List<CashFlowPoint>>((ref) async {
  final range = ref.watch(reportsRangeProvider);
  final service = ref.watch(reportServiceProvider);
  return service.cashFlowSeries(
    from: range.from,
    to: range.to,
    resolution: range.resolution,
  );
});

/// Spending grouped by category in the active range.
final spendingAnalysisProvider = FutureProvider<List<CategoryAmount>>((ref) async {
  final range = ref.watch(reportsRangeProvider);
  final service = ref.watch(reportServiceProvider);
  return service.expenseByCategory(from: range.from, to: range.to);
});

/// Income grouped by category in the active range.
final incomeAnalysisProvider = FutureProvider<List<CategoryAmount>>((ref) async {
  final range = ref.watch(reportsRangeProvider);
  final service = ref.watch(reportServiceProvider);
  return service.incomeByCategory(from: range.from, to: range.to);
});
