enum NetWorthGranularity {
  day,
  week,
  month;

  /// Day buckets for ranges up to ~2 months, week buckets up to ~6 months,
  /// month buckets beyond that — keeps the point count reasonable for a
  /// chart regardless of the selected range.
  factory NetWorthGranularity.forRange(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    if (days <= 62) return NetWorthGranularity.day;
    if (days <= 180) return NetWorthGranularity.week;
    return NetWorthGranularity.month;
  }
}

/// Net worth (sum of every account's balance) as of [date].
class NetWorthPoint {
  const NetWorthPoint({required this.date, required this.netWorth});

  final DateTime date;
  final double netWorth;
}
