/// Formats and parses the `incomePeriod` field stored on income
/// transactions: the calendar month (`YYYY-MM`, zero-padded) that income is
/// reported under, independent of the date money actually moved. Chosen as a
/// plain string so Firestore range queries (`>=`/`<=`) sort the same way a
/// chronological comparison would.
class IncomePeriod {
  const IncomePeriod._();

  static String of(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  /// The first instant of the month [key] names.
  static DateTime toMonth(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}
