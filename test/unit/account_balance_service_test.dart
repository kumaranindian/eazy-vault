import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/transactions/data/models/transaction_model.dart';
import '../../lib/features/transactions/domain/enums/transaction_type.dart';
import '../../lib/features/transactions/domain/services/account_balance_service.dart';
import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('AccountBalanceService', () {
    late AccountBalanceService service;
    late FakeFirebaseFirestore firestore;
    const userId = TestHelpers.testUserId;

    setUp(() async {
      firestore = MockFirebase.getFakeFirestore();
      service = AccountBalanceService(firestore: firestore);
      await MockFirebase.seedFirestore(firestore, userId);
    });

    group('updateBalanceForNewTransaction', () {
      test('should increase balance for income transaction', () async {
        final transaction = TransactionModel(
          id: 'new-transaction',
          type: TransactionType.income,
          amount: 1000.0,
          accountId: 'account-1',
          categoryId: 'category-2',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        await service.updateBalanceForNewTransaction(userId, transaction);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 11000.0);
      });

      test('should decrease balance for expense transaction', () async {
        final transaction = TransactionModel(
          id: 'new-transaction',
          type: TransactionType.expense,
          amount: 500.0,
          accountId: 'account-1',
          categoryId: 'category-1',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        await service.updateBalanceForNewTransaction(userId, transaction);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 9500.0);
      });

      test('should throw exception when account not found', () async {
        final transaction = TransactionModel(
          id: 'new-transaction',
          type: TransactionType.expense,
          amount: 500.0,
          accountId: 'non-existent-account',
          categoryId: 'category-1',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        expect(
          () => service.updateBalanceForNewTransaction(userId, transaction),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateBalanceForUpdatedTransaction', () {
      test('should adjust balance when amount changes (same account)', () async {
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

        final newTransaction = oldTransaction.copyWith(amount: 700.0);

        await service.updateBalanceForUpdatedTransaction(
          userId,
          oldTransaction,
          newTransaction,
        );

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 9800.0);
      });

      test('should adjust balance when type changes', () async {
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

        final newTransaction = oldTransaction.copyWith(
          type: TransactionType.income,
          categoryId: 'category-2',
        );

        await service.updateBalanceForUpdatedTransaction(
          userId,
          oldTransaction,
          newTransaction,
        );

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 11000.0);
      });

      test('should handle account change', () async {
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

        final newTransaction = oldTransaction.copyWith(accountId: 'account-2');

        await service.updateBalanceForUpdatedTransaction(
          userId,
          oldTransaction,
          newTransaction,
        );

        final account1Doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        final account2Doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-2')
            .get();

        expect(account1Doc.data()?['currentBalance'], 10500.0);
        expect(account2Doc.data()?['currentBalance'], 49500.0);
      });
    });

    group('revertBalanceForDeletedTransaction', () {
      test('should revert balance for deleted income transaction', () async {
        final transaction = TransactionModel(
          id: 'transaction-1',
          type: TransactionType.income,
          amount: 1000.0,
          accountId: 'account-1',
          categoryId: 'category-2',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        );

        await service.revertBalanceForDeletedTransaction(userId, transaction);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 9000.0);
      });

      test('should revert balance for deleted expense transaction', () async {
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

        await service.revertBalanceForDeletedTransaction(userId, transaction);

        final accountDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('accounts')
            .doc('account-1')
            .get();

        expect(accountDoc.data()?['currentBalance'], 10500.0);
      });
    });
  });
}
