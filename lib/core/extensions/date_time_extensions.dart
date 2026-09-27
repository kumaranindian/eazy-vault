import '../utils/date_time_utils.dart';

extension DateTimeExtensions on DateTime {
  String toFormattedDate() => DateTimeUtils.formatDate(this);

  String toFormattedTime() => DateTimeUtils.formatTime(this);

  String toFormattedDateTime() => DateTimeUtils.formatDateTime(this);

  String toFormattedDateShort() => DateTimeUtils.formatDateShort(this);

  String toFormattedMonthYear() => DateTimeUtils.formatMonthYear(this);

  String toRelative() => DateTimeUtils.formatRelative(this);

  bool get isToday => DateTimeUtils.isToday(this);

  bool get isYesterday => DateTimeUtils.isYesterday(this);

  bool get isThisWeek => DateTimeUtils.isThisWeek(this);

  bool get isThisMonth => DateTimeUtils.isThisMonth(this);

  DateTime get startOfDay => DateTimeUtils.startOfDay(this);

  DateTime get endOfDay => DateTimeUtils.endOfDay(this);

  DateTime get startOfMonth => DateTimeUtils.startOfMonth(this);

  DateTime get endOfMonth => DateTimeUtils.endOfMonth(this);

  DateTime get startOfWeek => DateTimeUtils.startOfWeek(this);

  DateTime get endOfWeek => DateTimeUtils.endOfWeek(this);

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  bool isBefore(DateTime other, {bool orSame = false}) {
    if (orSame) {
      return isBefore(other) || isAtSameMomentAs(other);
    }
    return isBefore(other);
  }

  bool isAfter(DateTime other, {bool orSame = false}) {
    if (orSame) {
      return isAfter(other) || isAtSameMomentAs(other);
    }
    return isAfter(other);
  }
}
