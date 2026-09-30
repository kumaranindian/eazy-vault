import 'package:eazyvault/core/extensions/double_extensions.dart';
import 'package:eazyvault/core/utils/currency_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyUtils', () {
    test('format puts the minus sign before the symbol', () {
      expect(CurrencyUtils.format(1234.5), '₹1,234.50');
      expect(CurrencyUtils.format(-1234.5), '-₹1,234.50');
      expect(CurrencyUtils.format(-0.001), '₹0.00');
    });

    test('formatWithSign never doubles the minus sign', () {
      expect(CurrencyUtils.formatWithSign(100), '+₹100.00');
      expect(CurrencyUtils.formatWithSign(-100), '-₹100.00');
    });

    test('formatCompact keeps the sign', () {
      expect(CurrencyUtils.formatCompact(-150000), '-₹1.50L');
      expect(CurrencyUtils.formatCompact(2500), '₹2.50K');
    });

    test('parse keeps a leading minus', () {
      expect(CurrencyUtils.parse('-₹1,234.50'), -1234.5);
      expect(CurrencyUtils.parse('₹1,234.50'), 1234.5);
    });
  });

  test('roundToDecimal rounds to the given number of places', () {
    expect(1.23456.roundToDecimal(2), 1.23);
    expect(1.235.roundToDecimal(1), 1.2);
  });
}
