import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../models/loan_metadata.dart';

class TransferService {
  TransferService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Create a transfer transaction between two accounts
  Future<void> createTransfer({
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    try {
      LoggerService.info('Creating transfer transaction');

      if (fromAccountId == toAccountId) {
        throw const ValidationException('Cannot transfer to the same account');
      }

      if (amount <= 0) {
        throw const ValidationException('Transfer amount must be positive');
      }

      final fromAccountRef = _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.accountsCollection)
          .doc(fromAccountId);

      final toAccountRef = _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.accountsCollection)
          .doc(toAccountId);

      await _firestore.runTransaction((transaction) async {
        // Get both accounts
        final fromAccountDoc = await transaction.get(fromAccountRef);
        final toAccountDoc = await transaction.get(toAccountRef);

        if (!fromAccountDoc.exists) {
          throw const NotFoundException('Source account not found');
        }
        if (!toAccountDoc.exists) {
          throw const NotFoundException('Destination account not found');
        }

        // Get current balances
        final fromBalance =
            (fromAccountDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;
        final toBalance =
            (toAccountDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;

        // Check if source account has sufficient balance
        if (fromBalance < amount) {
          throw const ValidationException('Insufficient balance in source account');
        }

        // Update balances
        final newFromBalance = fromBalance - amount;
        final newToBalance = toBalance + amount;

        transaction.update(fromAccountRef, {
          'currentBalance': newFromBalance,
          AppConstants.updatedAtField: Timestamp.now(),
        });

        transaction.update(toAccountRef, {
          'currentBalance': newToBalance,
          AppConstants.updatedAtField: Timestamp.now(),
        });
      });

      LoggerService.info('Transfer completed successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Transfer error', error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException('Failed to create transfer: ${e.toString()}');
    }
  }

  /// Reverse a transfer transaction
  Future<void> reverseTransfer({
    required String userId,
    required TransactionModel transferTransaction,
  }) async {
    try {
      LoggerService.info('Reversing transfer transaction');

      if (transferTransaction.type != TransactionType.transfer) {
        throw const ValidationException('Not a transfer transaction');
      }

      final metadata = transferTransaction.transferMetadata;
      if (metadata == null) {
        throw const ValidationException('Transfer metadata not found');
      }

      // Reverse the transfer by swapping from and to accounts
      await createTransfer(
        userId: userId,
        fromAccountId: metadata.toAccountId,
        toAccountId: metadata.fromAccountId,
        amount: transferTransaction.amount,
        date: DateTime.now(),
        description: 'Reversal: ${transferTransaction.description ?? "Transfer"}',
      );

      LoggerService.info('Transfer reversed successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Reverse transfer error', error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException('Failed to reverse transfer: ${e.toString()}');
    }
  }
}

extension on TransactionModel {
  TransferMetadata? get transferMetadata {
    if (metadata == null) return null;
    try {
      return TransferMetadata.fromJson(metadata!);
    } catch (e) {
      return null;
    }
  }
}
