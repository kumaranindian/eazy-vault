import 'package:intl/intl.dart';

import '../config/app_config.dart';

class CurrencyUtils {
  const CurrencyUtils._();

  static String format(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    final formattedAmount = formatter.format(amount);

    if (showSymbol) {
      return '${AppConfig.defaultCurrency}$formattedAmount';
    }

    return formattedAmount;
  }

  static String formatWithSign(double amount, {bool showSymbol = true}) {
    final sign = amount >= 0 ? '+' : '-';
    final formatted = format(amount, showSymbol: showSymbol);

    if (showSymbol) {
      return '$sign$formatted';
    }

    return '$sign$formatted';
  }

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

    if (showSymbol) {
      return '${AppConfig.defaultCurrency}$formattedAmount';
    }

    return formattedAmount;
  }

  static double? parse(String value) {
    final cleanedValue = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleanedValue);
  }
}
