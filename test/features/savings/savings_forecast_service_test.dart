import 'package:flutter_test/flutter_test.dart';

import 'package:perako/features/savings/domain/savings_forecast_service.dart';
import 'package:perako/features/savings/domain/savings_interest_service.dart';

void main() {
  group('SavingsForecastService', () {
    test('monthly compounding factor', () {
      final service = SavingsForecastService();
      expect(
        service.monthlyFactor(
          annualRate: 0.12,
          frequency: CompoundingFrequency.monthly,
        ),
        closeTo(1.01, 1e-12),
      );
    });

    test('forecast produces one point per month from month one', () {
      final service = SavingsForecastService();
      final points = service.forecast(
        principalCents: 100000,
        annualRate: 0.12,
        frequency: CompoundingFrequency.monthly,
        months: 12,
        from: DateTime(2026, 1, 1),
      );
      expect(points, hasLength(12));
      expect(points.first.balanceCents, 101000);
      expect(points.last.balanceCents, 112683);
      expect(points.last.date, DateTime(2026, 12, 31));
    });

    test('annual compounding grows slower than monthly', () {
      final service = SavingsForecastService();
      final monthly = service.forecast(
        principalCents: 100000,
        annualRate: 0.12,
        frequency: CompoundingFrequency.monthly,
        months: 12,
      );
      final annually = service.forecast(
        principalCents: 100000,
        annualRate: 0.12,
        frequency: CompoundingFrequency.annually,
        months: 12,
      );
      expect(monthly.last.balanceCents, greaterThan(annually.last.balanceCents));
    });

    test('zero rate keeps balance flat', () {
      final service = SavingsForecastService();
      final points = service.forecast(
        principalCents: 123456,
        annualRate: 0,
        frequency: CompoundingFrequency.daily,
        months: 6,
      );
      expect(points.last.balanceCents, 123456);
    });
  });
}
