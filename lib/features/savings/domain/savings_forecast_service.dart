import 'dart:math' as math;

import 'savings_interest_service.dart';

/// A single projected balance at a month end.
class ForecastPoint {
  const ForecastPoint({required this.date, required this.balanceCents});

  final DateTime date;
  final int balanceCents;
}

/// Projects how a savings balance grows under a compounding interest rate.
class SavingsForecastService {
  /// The equivalent monthly growth factor for [annualRate] compounding with
  /// the given [frequency].
  double monthlyFactor({
    required double annualRate,
    required CompoundingFrequency frequency,
  }) =>
      switch (frequency) {
        CompoundingFrequency.daily =>
          math.pow(1 + annualRate / 365, 365 / 12).toDouble(),
        CompoundingFrequency.monthly => 1 + annualRate / 12,
        CompoundingFrequency.annually =>
          math.pow(1 + annualRate, 1 / 12).toDouble(),
      };

  /// Forecasts [principalCents] growing at [annualRate] for [months] months,
  /// compounding according to [frequency].
  ///
  /// The first point is the balance at the end of the first month; the last is
  /// the balance at the end of month [months]. Daily and monthly compounding
  /// step the balance every month using the equivalent monthly factor, so the
  /// 12-month point lands on the exact annual result.
  List<ForecastPoint> forecast({
    required int principalCents,
    required double annualRate,
    required CompoundingFrequency frequency,
    int months = 12,
    DateTime? from,
  }) {
    final start = from ?? DateTime.now();
    final factor = monthlyFactor(annualRate: annualRate, frequency: frequency);

    var balance = principalCents.toDouble();
    final points = <ForecastPoint>[];
    for (var m = 1; m <= months; m++) {
      balance *= factor;
      final monthEnd = DateTime(start.year, start.month + m, 1)
          .subtract(const Duration(days: 1));
      points.add(ForecastPoint(
        date: monthEnd,
        balanceCents: balance.round(),
      ));
    }
    return points;
  }
}
