import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../models/loan_metadata.dart';

class LoanService {
  LoanService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Get all active loans (given and taken)
  Future<({List<TransactionModel> loansGiven, List<TransactionModel> loansTaken})>
      getActiveLoans(String userId) async {
    try {
      LoggerService.info('Fetching active loans for user: $userId');

      final transactionsRef = _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection);

      // Get loans given
      final loansGivenQuery = await transactionsRef
          .where('type', isEqualTo: TransactionType.loanGiven.name)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy('date', descending: true)
          .get();

      // Get loans taken
      final loansTakenQuery = await transactionsRef
          .where('type', isEqualTo: TransactionType.loanTaken.name)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy('date', descending: true)
          .get();

      final loansGiven = loansGivenQuery.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .where((loan) {
        final metadata = _getLoanMetadata(loan);
        return metadata?.status != LoanStatus.completed;
      }).toList();

      final loansTaken = loansTakenQuery.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .where((loan) {
        final metadata = _getLoanMetadata(loan);
        return metadata?.status != LoanStatus.completed;
      }).toList();

      LoggerService.info(
          'Found ${loansGiven.length} loans given and ${loansTaken.length} loans taken');

      return (loansGiven: loansGiven, loansTaken: loansTaken);
    } catch (e, stackTrace) {
      LoggerService.error('Get active loans error',
          error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch active loans: ${e.toString()}');
    }
  }

  /// Get overdue loans
  Future<List<TransactionModel>> getOverdueLoans(String userId) async {
    try {
      final loans = await getActiveLoans(userId);
      final allLoans = [...loans.loansGiven, ...loans.loansTaken];

      final now = DateTime.now();
      return allLoans.where((loan) {
        final metadata = _getLoanMetadata(loan);
        if (metadata == null || metadata.dueDate == null) return false;
        return metadata.status != LoanStatus.completed &&
            metadata.dueDate!.isBefore(now);
      }).toList();
    } catch (e, stackTrace) {
      LoggerService.error('Get overdue loans error',
          error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch overdue loans: ${e.toString()}');
    }
  }

  /// Record a loan repayment
  Future<void> recordRepayment({
    required String userId,
    required String loanTransactionId,
    required double repaymentAmount,
    required String accountId,
    required DateTime date,
    String? notes,
  }) async {
    try {
      LoggerService.info('Recording loan repayment');

      if (repaymentAmount <= 0) {
        throw const ValidationException('Repayment amount must be positive');
      }

      final loanRef = _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection)
          .doc(loanTransactionId);

      await _firestore.runTransaction((transaction) async {
        final loanDoc = await transaction.get(loanRef);

        if (!loanDoc.exists) {
          throw const NotFoundException('Loan transaction not found');
        }

        final loanData = loanDoc.data()!;
        final metadata = loanData['metadata'] as Map<String, dynamic>?;

        if (metadata == null) {
          throw const ValidationException('Loan metadata not found');
        }

        final loanMetadata = LoanMetadata.fromJson(metadata);
        final remainingAmount = loanMetadata.remainingAmount ??
            loanMetadata.originalAmount ??
            (loanData['amount'] as num).toDouble();

        if (repaymentAmount > remainingAmount) {
          throw const ValidationException(
              'Repayment amount exceeds remaining loan amount');
        }

        final newRemainingAmount = remainingAmount - repaymentAmount;
        final newStatus = newRemainingAmount == 0
            ? LoanStatus.completed
            : newRemainingAmount < remainingAmount
                ? LoanStatus.partial
                : loanMetadata.status;

        final updatedMetadata = loanMetadata.copyWith(
          remainingAmount: newRemainingAmount,
          status: newStatus,
        );

        transaction.update(loanRef, {
          'metadata': updatedMetadata.toJson(),
          AppConstants.updatedAtField: Timestamp.now(),
        });
      });

      LoggerService.info('Loan repayment recorded successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Record repayment error',
          error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException('Failed to record repayment: ${e.toString()}');
    }
  }

  /// Calculate total amount owed to you
  Future<double> getTotalOwedToYou(String userId) async {
    try {
      final loans = await getActiveLoans(userId);
      return loans.loansGiven.fold<double>(0, (sum, loan) {
        final metadata = _getLoanMetadata(loan);
        return sum + (metadata?.remainingAmount ?? loan.amount);
      });
    } catch (e) {
      LoggerService.error('Get total owed error', error: e);
      return 0;
    }
  }

  /// Calculate total amount you owe
  Future<double> getTotalYouOwe(String userId) async {
    try {
      final loans = await getActiveLoans(userId);
      return loans.loansTaken.fold<double>(0, (sum, loan) {
        final metadata = _getLoanMetadata(loan);
        return sum + (metadata?.remainingAmount ?? loan.amount);
      });
    } catch (e) {
      LoggerService.error('Get total you owe error', error: e);
      return 0;
    }
  }

  LoanMetadata? _getLoanMetadata(TransactionModel transaction) {
    if (transaction.metadata == null) return null;
    try {
      return LoanMetadata.fromJson(transaction.metadata!);
    } catch (e) {
      return null;
    }
  }
}
