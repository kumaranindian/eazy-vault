import 'package:intl/intl.dart';

import '../config/app_config.dart';

class CurrencyUtils {
  const CurrencyUtils._();

  /// Formats as `₹1,23,456.78`; negatives as `-₹1,23,456.78` (sign before
  /// the currency symbol).
  static String format(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    final formattedAmount = formatter.format(amount.abs());
    final sign = _isNegative(amount) ? '-' : '';

    if (showSymbol) {
      return '$sign${AppConfig.defaultCurrency}$formattedAmount';
    }

    return '$sign$formattedAmount';
  }

  /// Like [format] but always shows the sign: `+₹100.00` / `-₹100.00`.
  static String formatWithSign(double amount, {bool showSymbol = true}) {
    final sign = _isNegative(amount) ? '-' : '+';
    return '$sign${format(amount.abs(), showSymbol: showSymbol)}';
  }

  /// Amounts that round to -0.00 are shown without a minus sign.
  static bool _isNegative(double amount) => amount <= -0.005;

  static String formatCompact(double amount, {bool showSymbol = true}) {
    final absAmount = amount.abs();
    String formattedAmount;

    if (absAmount >= 10000000) {
      formattedAmount = '${(absAmount / 10000000).toStringAsFixed(2)}Cr';
    } else if (absAmount >= 100000) {
      formattedAmount = '${(absAmount / 100000).toStringAsFixed(2)}L';
    } else if (absAmount >= 1000) {
      formattedAmount = '${(absAmount / 1000).toStringAsFixed(2)}K';
    } else {
      formattedAmount = absAmount.toStringAsFixed(2);
    }

    final sign = _isNegative(amount) ? '-' : '';

    if (showSymbol) {
      return '$sign${AppConfig.defaultCurrency}$formattedAmount';
    }

    return '$sign$formattedAmount';
  }

  /// Parses user/formatted input such as `-₹1,234.50`, keeping the sign.
  static double? parse(String value) {
    final trimmed = value.trim();
    final isNegative = trimmed.startsWith('-');
    final cleanedValue = trimmed.replaceAll(RegExp(r'[^\d.]'), '');
    final parsed = double.tryParse(cleanedValue);
    if (parsed == null) return null;
    return isNegative ? -parsed : parsed;
  }
}
