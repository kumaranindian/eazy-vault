import 'package:eazyvault/features/csv_import/domain/models/csv_column_mapping.dart';
import 'package:eazyvault/features/csv_import/domain/models/parsed_csv_row.dart';
import 'package:eazyvault/features/csv_import/domain/services/csv_import_service.dart';
import 'package:eazyvault/features/transactions/data/datasources/transactions_remote_datasource.dart';
import 'package:eazyvault/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  const userId = TestHelpers.testUserId;

  CsvImportService buildService(FakeFirebaseFirestore firestore) {
    return CsvImportService(
      transactionsRepository: TransactionsRepositoryImpl(
        remoteDataSource: TransactionsRemoteDataSourceImpl(firestore: firestore),
        balanceService: AccountBalanceService(firestore: firestore),
      ),
    );
  }

  group('parseRaw', () {
    test('throws on an empty file', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      expect(() => service.parseRaw(''), throwsFormatException);
    });

    test('splits a simple CSV into rows of cells', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      final rows = service.parseRaw('Date,Description,Amount\n2026-01-05,Coffee,-150.00\n');
      expect(rows, [
        ['Date', 'Description', 'Amount'],
        ['2026-01-05', 'Coffee', '-150.00'],
      ]);
    });
  });

  group('applyMapping — dates', () {
    test('accepts several common date formats', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, amountColumn: 1);
      final rows = service.applyMapping([
        ['2026-01-05', '-100'],
        ['05/01/2026', '-100'],
        ['05-Jan-2026', '-100'],
      ], mapping);

      expect(rows.every((r) => r.status == CsvRowStatus.valid), isTrue);
      expect(rows.every((r) => r.date == DateTime(2026, 1, 5)), isTrue);
    });

    test('marks an unrecognized date invalid', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, amountColumn: 1);
      final rows = service.applyMapping([
        ['not-a-date', '-100'],
      ], mapping);

      expect(rows.single.status, CsvRowStatus.invalid);
      expect(rows.single.included, isFalse);
    });
  });

  group('applyMapping — amounts', () {
    test('a signed amount column needs no type hint', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, amountColumn: 1);
      final rows = service.applyMapping([
        ['2026-01-05', '-150.00'],
        ['2026-01-06', '2000.00'],
      ], mapping);

      expect(rows[0].amount, -150.0);
      expect(rows[0].isIncome, isFalse);
      expect(rows[1].amount, 2000.0);
      expect(rows[1].isIncome, isTrue);
    });

    test('strips currency symbols and thousands separators', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, amountColumn: 1);
      final rows = service.applyMapping([
        ['2026-01-05', '-₹1,234.50'],
      ], mapping);

      expect(rows.single.amount, -1234.50);
    });

    test('separate debit/credit columns', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, debitColumn: 1, creditColumn: 2);
      final rows = service.applyMapping([
        ['2026-01-05', '500', ''],
        ['2026-01-06', '', '2000'],
      ], mapping);

      expect(rows[0].amount, -500.0);
      expect(rows[1].amount, 2000.0);
    });

    test('a row with both debit and credit is invalid', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, debitColumn: 1, creditColumn: 2);
      final rows = service.applyMapping([
        ['2026-01-05', '500', '200'],
      ], mapping);

      expect(rows.single.status, CsvRowStatus.invalid);
    });

    test('an empty amount is invalid, not zero', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, amountColumn: 1);
      final rows = service.applyMapping([
        ['2026-01-05', ''],
      ], mapping);

      expect(rows.single.status, CsvRowStatus.invalid);
    });

    test('an unsigned amount is resolved by a type column', () {
      final service = buildService(MockFirebase.getFakeFirestore());
      const mapping = CsvColumnMapping(dateColumn: 0, amountColumn: 1, typeColumn: 2);
      final rows = service.applyMapping([
        ['2026-01-05', '500', 'Debit'],
        ['2026-01-06', '500', 'Credit'],
      ], mapping);

      expect(rows[0].amount, -500.0);
      expect(rows[1].amount, 500.0);
    });
  });

  group('markDuplicates + import', () {
    test('a row matching an existing transaction is flagged and excluded', () async {
      final firestore = MockFirebase.getFakeFirestore();
      await MockFirebase.seedFirestore(firestore, userId);
      final service = buildService(firestore);

      // Seeded transaction-1: expense 500 on account-1, dated "now",
      // description "Lunch at restaurant".
      final today = DateTime.now();
      const mapping = CsvColumnMapping(dateColumn: 0, descriptionColumn: 1, amountColumn: 2);
      final dateText = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      var rows = service.applyMapping([
        [dateText, 'Lunch at restaurant', '-500'],
        [dateText, 'Groceries', '-200'],
      ], mapping);

      rows = await service.markDuplicates(userId, 'account-1', rows);

      expect(rows[0].status, CsvRowStatus.duplicate);
      expect(rows[1].status, CsvRowStatus.valid);

      final outcome = await service.import(
        userId,
        accountId: 'account-1',
        incomeCategoryId: 'category-2',
        expenseCategoryId: 'category-1',
        categoryIdsByName: const {},
        rows: rows,
      );

      expect(outcome.imported, 1);
      expect(outcome.skippedDuplicates, 1);
    });
  });
}
