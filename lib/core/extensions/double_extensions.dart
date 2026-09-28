import 'dart:math' as math;

import '../utils/currency_utils.dart';

extension DoubleExtensions on double {
  String toCurrency({bool showSymbol = true}) {
    return CurrencyUtils.format(this, showSymbol: showSymbol);
  }

  String toCurrencyWithSign({bool showSymbol = true}) {
    return CurrencyUtils.formatWithSign(this, showSymbol: showSymbol);
  }

  String toCurrencyCompact({bool showSymbol = true}) {
    return CurrencyUtils.formatCompact(this, showSymbol: showSymbol);
  }

  double roundToDecimal(int places) {
    final mod = math.pow(10, places).toDouble();
    return (this * mod).round() / mod;
  }
}
