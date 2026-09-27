import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/transaction_model.dart';

class AccountBalanceService {
  AccountBalanceService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> updateBalanceForNewTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    try {
      LoggerService.info('Updating balance for new transaction');

      final accountRef = _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.accountsCollection)
          .doc(transaction.accountId);

      await _firestore.runTransaction((firestoreTransaction) async {
        final accountDoc = await firestoreTransaction.get(accountRef);

        if (!accountDoc.exists) {
          throw const NotFoundException('Account not found');
        }

        final currentBalance = (accountDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;

        final newBalance = transaction.isIncome
            ? currentBalance + transaction.amount
            : currentBalance - transaction.amount;

        firestoreTransaction.update(accountRef, {
          'currentBalance': newBalance,
          AppConstants.updatedAtField: Timestamp.now(),
        });
      });

      LoggerService.info('Balance updated successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Update balance error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update account balance: ${e.toString()}');
    }
  }

  Future<void> updateBalanceForUpdatedTransaction(
    String userId,
    TransactionModel oldTransaction,
    TransactionModel newTransaction,
  ) async {
    try {
      LoggerService.info('Updating balance for updated transaction');

      if (oldTransaction.accountId == newTransaction.accountId) {
        final accountRef = _firestore
            .collection(AppConstants.userCollection)
            .doc(userId)
            .collection(AppConstants.accountsCollection)
            .doc(newTransaction.accountId);

        await _firestore.runTransaction((firestoreTransaction) async {
          final accountDoc = await firestoreTransaction.get(accountRef);

          if (!accountDoc.exists) {
            throw const NotFoundException('Account not found');
          }

          final currentBalance = (accountDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;

          var newBalance = currentBalance;

          if (oldTransaction.isIncome) {
            newBalance -= oldTransaction.amount;
          } else {
            newBalance += oldTransaction.amount;
          }

          if (newTransaction.isIncome) {
            newBalance += newTransaction.amount;
          } else {
            newBalance -= newTransaction.amount;
          }

          firestoreTransaction.update(accountRef, {
            'currentBalance': newBalance,
            AppConstants.updatedAtField: Timestamp.now(),
          });
        });
      } else {
        await _revertBalance(userId, oldTransaction);
        await updateBalanceForNewTransaction(userId, newTransaction);
      }

      LoggerService.info('Balance updated successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Update balance error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update account balance: ${e.toString()}');
    }
  }

  Future<void> revertBalanceForDeletedTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    try {
      LoggerService.info('Reverting balance for deleted transaction');
      await _revertBalance(userId, transaction);
      LoggerService.info('Balance reverted successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Revert balance error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to revert account balance: ${e.toString()}');
    }
  }

  Future<void> _revertBalance(String userId, TransactionModel transaction) async {
    final accountRef = _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.accountsCollection)
        .doc(transaction.accountId);

    await _firestore.runTransaction((firestoreTransaction) async {
      final accountDoc = await firestoreTransaction.get(accountRef);

      if (!accountDoc.exists) {
        throw const NotFoundException('Account not found');
      }

      final currentBalance = (accountDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;

      final newBalance = transaction.isIncome
          ? currentBalance - transaction.amount
          : currentBalance + transaction.amount;

      firestoreTransaction.update(accountRef, {
        'currentBalance': newBalance,
        AppConstants.updatedAtField: Timestamp.now(),
      });
    });
  }
}
