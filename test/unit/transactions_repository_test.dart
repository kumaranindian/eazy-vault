import 'package:flutter_test/flutter_test.dart';

import 'package:eazyvault/features/transactions/data/datasources/transactions_remote_datasource.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('TransactionsRepository', () {
    late TransactionsRepositoryImpl repository;
    late FakeFirebaseFirestore firestore;
    late AccountBalanceService balanceService;
    const userId = TestHelpers.testUserId;

    setUp(() async {
      firestore = MockFirebase.getFakeFirestore();
      balanceService = AccountBalanceService(firestore: firestore);
      final dataSource = TransactionsRemoteDataSourceImpl(firestore: firestore);
      repository = TransactionsRepositoryImpl(
        remoteDataSource: dataSource,
        balanceService: balanceService,
      );
      await MockFirebase.seedFirestore(firestore, userId);
    });

    group('getTransactions', () {
      test('should return list of transactions', () async {
        final result = await repository.getTransactions(userId);

        expect(result.failure, isNull);
        expect(result.transactions, isNotEmpty);
        expect(result.transactions.length, 1);
      });

      test('should filter by transaction type', () async {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .add({
          'type': 'income',
          'amount': 5000.0,
          'accountId': 'account-1',
          'categoryId': 'category-2',
          'date': TestHelpers.getTestTimestamp(),
          'createdAt': TestHelpers.getTestTimestamp(),
          'updatedAt': TestHelpers.getTestTimestamp(),
          'createdBy': userId,
          'isDeleted': false,
        });

        final result = await repository.getTransactions(
          userId,
          type: TransactionType.income,
        );

        expect(result.failure, isNull);
        expect(result.transactions.length, 1);
        expect(result.transactions.first.type, TransactionType.income);
      });

      test('should filter by account', () async {
        final result = await repository.getTransactions(
          userId,
          accountId: 'account-1',
        );

        expect(result.failure, isNull);
        expect(result.transactions.every((t) => t.accountId == 'account-1'),
            isTrue);
      });

      test('should filter by category', () async {
        final result = await repository.getTransactions(
          userId,
          categoryId: 'category-1',
        );

        expect(result.failure, isNull);
        expect(result.transactions.every((t) => t.categoryId == 'category-1'),
            isTrue);
      });
    });

    group('createTransaction', () {
      test('should create transaction and update balance', () async {
        final transaction = TransactionModel(
          id: '',
          type: TransactionType.expense,
          amount: 200.0,
          accountId: 'account-1',
          categoryId: 'category-1',
          date: DateTime.now(),
          description: 'Test transaction',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        final result = await repository.createTransaction(userId, transaction);

        expect(result.failure, isNull);
        expect(result.transaction?.id, isNotEmpty);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 9800.0);
      });
    });

    group('updateTransaction', () {
      test('should update transaction and adjust balance', () async {
        final oldTransaction = TransactionModel(
          id: 'transaction-1',
          type: TransactionType.expense,
          amount: 500.0,
          accountId: 'account-1',
          categoryId: 'category-1',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        final newTransaction = oldTransaction.copyWith(amount: 300.0);

        final result = await repository.updateTransaction(
          userId,
          newTransaction,
        );

        expect(result.failure, isNull);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 10200.0);
      });
    });

    group('deleteTransaction', () {
      test('should soft delete transaction and revert balance', () async {
        final transaction = TransactionModel(
          id: 'transaction-1',
          type: TransactionType.expense,
          amount: 500.0,
          accountId: 'account-1',
          categoryId: 'category-1',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        final failure = await repository.deleteTransaction(
          userId,
          'transaction-1',
          transaction,
        );

        expect(failure, isNull);

        final transactionDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc('transaction-1')
            .get();

        expect(transactionDoc.data()?['isDeleted'], isTrue);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 10500.0);
      });
    });

    group('getTotalByType', () {
      test('should calculate total for income', () async {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .add({
          'type': 'income',
          'amount': 5000.0,
          'accountId': 'account-1',
          'categoryId': 'category-2',
          'date': TestHelpers.getTestTimestamp(),
          'createdAt': TestHelpers.getTestTimestamp(),
          'updatedAt': TestHelpers.getTestTimestamp(),
          'createdBy': userId,
          'isDeleted': false,
        });

        final result = await repository.getTotalByType(
          userId,
          TransactionType.income,
        );

        expect(result.total, 5000.0);
      });

      test('should calculate total for expense', () async {
        final result = await repository.getTotalByType(
          userId,
          TransactionType.expense,
        );

        expect(result.total, 500.0);
      });
    });
  });
}
