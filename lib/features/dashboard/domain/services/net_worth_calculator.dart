import '../models/net_worth_point.dart';

/// A balance-affecting transaction's date and its signed contribution to
/// total net worth (already resolved per-account via
/// `AccountBalanceService.signedAmountFor` and summed across accounts for
/// that date — see `NetWorthService`).
typedef NetWorthDelta = ({DateTime date, double delta});

/// Pure bucketing math for a net-worth-over-time series — no Firestore. Kept
/// separate from `NetWorthService` so the math is trivial to unit test.
class NetWorthCalculator {
  const NetWorthCalculator._();

  /// Builds one [NetWorthPoint] per bucket boundary in `[startDate, endDate]`.
  /// [deltas] may include entries dated before [startDate] — those correctly
  /// seed the opening net worth at the first bucket, the same way an account
  /// statement's "Opening Balance" folds in everything before its range.
  static List<NetWorthPoint> build({
    required double openingNetWorth,
    required List<NetWorthDelta> deltas,
    required DateTime startDate,
    required DateTime endDate,
    required NetWorthGranularity granularity,
  }) {
    final sorted = [...deltas]..sort((a, b) => a.date.compareTo(b.date));
    final boundaries = _bucketBoundaries(startDate, endDate, granularity);

    final points = <NetWorthPoint>[];
    var cumulative = openingNetWorth;
    var index = 0;
    for (final boundary in boundaries) {
      final endOfBoundaryDay =
          DateTime(boundary.year, boundary.month, boundary.day, 23, 59, 59, 999);
      while (index < sorted.length && !sorted[index].date.isAfter(endOfBoundaryDay)) {
        cumulative += sorted[index].delta;
        index++;
      }
      points.add(NetWorthPoint(date: boundary, netWorth: cumulative));
    }
    return points;
  }

  static List<DateTime> _bucketBoundaries(
    DateTime start,
    DateTime end,
    NetWorthGranularity granularity,
  ) {
    final last = DateTime(end.year, end.month, end.day);
    var cursor = DateTime(start.year, start.month, start.day);
    if (cursor.isAfter(last)) return [last];

    final boundaries = <DateTime>[];
    while (!cursor.isAfter(last)) {
      boundaries.add(cursor);
      cursor = switch (granularity) {
        NetWorthGranularity.day => cursor.add(const Duration(days: 1)),
        NetWorthGranularity.week => cursor.add(const Duration(days: 7)),
        NetWorthGranularity.month => DateTime(cursor.year, cursor.month + 1, cursor.day),
      };
    }
    if (boundaries.last != last) boundaries.add(last);
    return boundaries;
  }
}
