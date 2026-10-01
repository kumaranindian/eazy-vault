import 'package:flutter_test/flutter_test.dart';

import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/extensions/transaction_extensions.dart';
import 'package:eazyvault/features/transactions/domain/utils/income_period.dart';

void main() {
  group('IncomePeriod', () {
    test('formats a date as zero-padded YYYY-MM', () {
      expect(IncomePeriod.of(DateTime(2026, 1, 5)), '2026-01');
      expect(IncomePeriod.of(DateTime(2026, 10, 30)), '2026-10');
    });

    test('parses a key back to the first of that month', () {
      expect(IncomePeriod.toMonth('2026-10'), DateTime(2026, 10));
      expect(IncomePeriod.toMonth('2027-01'), DateTime(2027, 1));
    });
  });

  group('TransactionModelExtensions income period', () {
    TransactionModel income({required DateTime date, String? incomePeriod}) {
      final now = DateTime.now();
      return TransactionModel(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 50000,
        accountId: 'account-1',
        categoryId: 'category-2',
        date: date,
        incomePeriod: incomePeriod,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );
    }

    test('effectiveIncomePeriod uses the explicit incomePeriod when set', () {
      final t = income(date: DateTime(2026, 9, 30), incomePeriod: '2026-10');
      expect(t.effectiveIncomePeriod, '2026-10');
      expect(t.incomeReportingMonth, DateTime(2026, 10));
    });

    test('effectiveIncomePeriod falls back to the credited date\'s month when unset', () {
      final t = income(date: DateTime(2026, 6, 15));
      expect(t.effectiveIncomePeriod, '2026-06');
      expect(t.incomeReportingMonth, DateTime(2026, 6));
    });

    test('hasDistinctIncomePeriod is false for the default (same-month) relationship', () {
      final sameMonth = income(date: DateTime(2026, 10, 1), incomePeriod: '2026-10');
      expect(sameMonth.hasDistinctIncomePeriod, isFalse);

      final noPeriod = income(date: DateTime(2026, 10, 1));
      expect(noPeriod.hasDistinctIncomePeriod, isFalse);
    });

    test('hasDistinctIncomePeriod is true when the reporting month differs', () {
      final t = income(date: DateTime(2026, 9, 30), incomePeriod: '2026-10');
      expect(t.hasDistinctIncomePeriod, isTrue);
    });

    test('expense transactions are unaffected by incomePeriod', () {
      final now = DateTime.now();
      final expense = TransactionModel(
        id: 'tx-2',
        type: TransactionType.expense,
        amount: 10000,
        accountId: 'account-1',
        categoryId: 'category-1',
        date: DateTime(2026, 10, 1),
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );
      expect(expense.effectiveIncomePeriod, '2026-10');
      expect(expense.hasDistinctIncomePeriod, isFalse);
    });
  });
}
