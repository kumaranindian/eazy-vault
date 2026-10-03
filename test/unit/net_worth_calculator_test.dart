import 'package:eazyvault/features/dashboard/domain/models/net_worth_point.dart';
import 'package:eazyvault/features/dashboard/domain/services/net_worth_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetWorthCalculator.build', () {
    test('folds deltas before the range into the opening point', () {
      final points = NetWorthCalculator.build(
        openingNetWorth: 1000,
        deltas: [
          (date: DateTime(2026, 1, 1), delta: 200), // before the range
          (date: DateTime(2026, 2, 5), delta: 300),
        ],
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 10),
        granularity: NetWorthGranularity.day,
      );

      expect(points.first.date, DateTime(2026, 2, 1));
      expect(points.first.netWorth, 1200); // 1000 + the Jan 1 delta
      expect(points.last.date, DateTime(2026, 2, 10));
      expect(points.last.netWorth, 1500); // + the Feb 5 delta
    });

    test('a step only appears on or after the day it happened', () {
      final points = NetWorthCalculator.build(
        openingNetWorth: 0,
        deltas: [(date: DateTime(2026, 2, 5, 18), delta: 500)],
        startDate: DateTime(2026, 2, 3),
        endDate: DateTime(2026, 2, 7),
        granularity: NetWorthGranularity.day,
      );

      final byDate = {for (final p in points) p.date: p.netWorth};
      expect(byDate[DateTime(2026, 2, 4)], 0);
      expect(byDate[DateTime(2026, 2, 5)], 500);
      expect(byDate[DateTime(2026, 2, 7)], 500);
    });

    test('always includes the end date even off the granularity stride', () {
      final points = NetWorthCalculator.build(
        openingNetWorth: 0,
        deltas: const [],
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
        granularity: NetWorthGranularity.week,
      );
      expect(points.last.date, DateTime(2026, 1, 10));
    });
  });

  group('NetWorthGranularity.forRange', () {
    test('picks day/week/month by range length', () {
      final start = DateTime(2026, 1, 1);
      expect(
        NetWorthGranularity.forRange(start, start.add(const Duration(days: 30))),
        NetWorthGranularity.day,
      );
      expect(
        NetWorthGranularity.forRange(start, start.add(const Duration(days: 120))),
        NetWorthGranularity.week,
      );
      expect(
        NetWorthGranularity.forRange(start, start.add(const Duration(days: 400))),
        NetWorthGranularity.month,
      );
    });
  });
}
