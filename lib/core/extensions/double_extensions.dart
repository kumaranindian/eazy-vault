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
    final mod = 10.0 * places;
    return (this * mod).round() / mod;
  }
}
