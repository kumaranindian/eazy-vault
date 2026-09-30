import '../../data/models/recurring_transaction_model.dart';
import '../enums/recurrence_frequency.dart';

extension RecurringTransactionModelExtensions on RecurringTransactionModel {
  /// The next occurrence date that hasn't been generated yet: [startDate]
  /// itself if nothing has ever been generated, otherwise one period after
  /// [lastGeneratedDate].
  DateTime get nextDueDate {
    final last = lastGeneratedDate;
    if (last == null) return startDate;

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return last.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return last.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        return DateTime(last.year, last.month + 1, last.day);
    }
  }

  /// True once [nextDueDate] has moved past [endDate] — the rule has no more
  /// occurrences left to generate.
  bool get isFinished {
    final end = endDate;
    if (end == null) return false;
    return nextDueDate.isAfter(end);
  }

  /// Whether [nextDueDate] falls on or before [asOf]'s calendar day.
  bool isDueBy(DateTime asOf) {
    if (!isActive || isFinished) return false;
    final endOfDay = DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59);
    return !nextDueDate.isAfter(endOfDay);
  }
}
