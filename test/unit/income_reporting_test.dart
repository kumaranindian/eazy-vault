import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:eazyvault/features/transactions/data/datasources/transactions_remote_datasource.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/extensions/transaction_extensions.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

/// Covers the "income reporting period" business rule: an income's monthly
/// report follows `incomePeriod`, while the account balance always follows
/// the actual credited `date`. See CLAUDE.md "Income Reporting Period".
void main() {
  group('Income reporting period', () {
    late TransactionsRepositoryImpl repository;
    late AccountBalanceService balanceService;
    late FakeFirebaseFirestore firestore;
    const userId = TestHelpers.testUserId;
    const accountId = 'account-1';

    setUp(() async {
      firestore = MockFirebase.getFakeFirestore();
      balanceService = AccountBalanceService(firestore: firestore);
      repository = TransactionsRepositoryImpl(
        remoteDataSource: TransactionsRemoteDataSourceImpl(firestore: firestore),
        balanceService: balanceService,
      );

      await firestore.collection('users').doc(userId).collection('accounts').doc(accountId).set({
        'name': 'Cash',
        'type': 'cash',
        'currentBalance': 0.0,
        'openingBalance': 0.0,
        'color': 0xFF4CAF50,
        'icon': '💵',
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': userId,
        'isDeleted': false,
      });
    });

    Future<double> accountBalance() async {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(accountId)
          .get();
      return (doc.data()?['currentBalance'] as num).toDouble();
    }

    TransactionModel buildTransaction({
      required TransactionType type,
      required double amount,
      required DateTime date,
      String? incomePeriod,
      String categoryId = 'category-2',
    }) {
      final now = DateTime.now();
      return TransactionModel(
        id: '',
        type: type,
        amount: amount,
        accountId: accountId,
        categoryId: categoryId,
        date: date,
        incomePeriod: incomePeriod,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
      );
    }

    Future<double> totalFor(TransactionType type, DateTime start, DateTime end) async {
      final result = await repository.getTotalByType(userId, type, startDate: start, endDate: end);
      expect(result.failure, isNull);
      return result.total;
    }

    test(
        'TEST 1: income credited Sep 30 reported for October counts toward October, '
        'balance reflects the actual credit/debit dates', () async {
      final incomeResult = await repository.createTransaction(
        userId,
        buildTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 9, 30),
          incomePeriod: '2026-10',
        ),
      );
      expect(incomeResult.failure, isNull);

      final expenseResult = await repository.createTransaction(
        userId,
        buildTransaction(
          type: TransactionType.expense,
          amount: 10000,
          date: DateTime(2026, 10, 1),
          categoryId: 'category-1',
        ),
      );
      expect(expenseResult.failure, isNull);

      final octStart = DateTime(2026, 10, 1);
      final octEnd = DateTime(2026, 10, 31, 23, 59, 59);

      final octIncome = await totalFor(TransactionType.income, octStart, octEnd);
      final octExpense = await totalFor(TransactionType.expense, octStart, octEnd);

      expect(octIncome, 50000);
      expect(octExpense, 10000);
      expect(octIncome - octExpense, 40000); // Net Savings
      expect(await accountBalance(), 40000); // +50000 on Sep 30, -10000 on Oct 1
    });

    test('TEST 2: incomePeriod September keeps a Sep 30 income out of October totals', () async {
      await repository.createTransaction(
        userId,
        buildTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 9, 30),
          incomePeriod: '2026-09',
        ),
      );

      final sepTotal =
          await totalFor(TransactionType.income, DateTime(2026, 9, 1), DateTime(2026, 9, 30, 23, 59, 59));
      final octTotal =
          await totalFor(TransactionType.income, DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59));

      expect(sepTotal, 50000);
      expect(octTotal, 0);
    });

    test('TEST 3: Dec 31 credited income reported for January counts in January next year, '
        'while December\'s balance already reflects the credit', () async {
      await repository.createTransaction(
        userId,
        buildTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 12, 31),
          incomePeriod: '2027-01',
        ),
      );

      // Account balance follows the actual credited date, not the period.
      expect(await accountBalance(), 50000);

      final janTotal =
          await totalFor(TransactionType.income, DateTime(2027, 1, 1), DateTime(2027, 1, 31, 23, 59, 59));
      final decTotal =
          await totalFor(TransactionType.income, DateTime(2026, 12, 1), DateTime(2026, 12, 31, 23, 59, 59));

      expect(janTotal, 50000);
      expect(decTotal, 0);
    });

    test('TEST 4: income written before incomePeriod existed falls back to its credited month',
        () async {
      // Written directly to Firestore (no `incomePeriod` key at all), like
      // data from before this field existed.
      await firestore.collection('users').doc(userId).collection('transactions').doc('legacy-income').set({
        'type': 'income',
        'amount': 20000.0,
        'accountId': accountId,
        'categoryId': 'category-2',
        'date': Timestamp.fromDate(DateTime(2026, 6, 15)),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': userId,
        'isDeleted': false,
      });

      final loaded = await repository.getTransaction(userId, 'legacy-income');
      expect(loaded.transaction, isNotNull);
      expect(loaded.transaction!.incomePeriod, isNull);
      expect(loaded.transaction!.effectiveIncomePeriod, '2026-06');

      final juneTotal =
          await totalFor(TransactionType.income, DateTime(2026, 6, 1), DateTime(2026, 6, 30, 23, 59, 59));
      expect(juneTotal, 20000);
    });

    test('TEST 5: changing incomePeriod moves monthly reports but never the account balance',
        () async {
      final created = await repository.createTransaction(
        userId,
        buildTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 9, 15),
          incomePeriod: '2026-09',
        ),
      );
      expect(created.failure, isNull);
      final balanceAfterCreate = await accountBalance();

      final updateResult = await repository.updateTransaction(
        userId,
        created.transaction!.copyWith(incomePeriod: '2026-10'),
      );
      expect(updateResult.failure, isNull);

      final sepTotal =
          await totalFor(TransactionType.income, DateTime(2026, 9, 1), DateTime(2026, 9, 30, 23, 59, 59));
      final octTotal =
          await totalFor(TransactionType.income, DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59));

      expect(sepTotal, 0);
      expect(octTotal, 50000);
      expect(await accountBalance(), balanceAfterCreate); // unchanged by the period edit
    });

    test('TEST 6: deleting an income decreases its reporting month and reverts the balance '
        'using its credited date', () async {
      final created = await repository.createTransaction(
        userId,
        buildTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 9, 30),
          incomePeriod: '2026-10',
        ),
      );
      expect(created.failure, isNull);
      final balanceBeforeDelete = await accountBalance();

      final failure = await repository.deleteTransaction(
        userId,
        created.transaction!.id,
        created.transaction!,
      );
      expect(failure, isNull);

      final octTotal =
          await totalFor(TransactionType.income, DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59));
      expect(octTotal, 0);
      expect(await accountBalance(), balanceBeforeDelete - 50000);
    });
  });
}
