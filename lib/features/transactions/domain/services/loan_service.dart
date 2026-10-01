import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../models/loan_metadata.dart';
import 'account_balance_service.dart';
import '../../../../core/utils/error_messages.dart';

class LoanService {
  LoanService({
    required FirebaseFirestore firestore,
    required AccountBalanceService balanceService,
  })  : _firestore = firestore,
        _balanceService = balanceService;

  final FirebaseFirestore _firestore;
  final AccountBalanceService _balanceService;

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
      throw ServerException(ErrorMessages.from(e, action: 'load active loans'));
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
      throw ServerException(ErrorMessages.from(e, action: 'load overdue loans'));
    }
  }

  /// Records [repayment] (a `loanRepayment` transaction linked to a loan via
  /// `metadata.linkedLoanId`).
  ///
  /// The repayment record, the account balance change and the loan's
  /// remaining amount/status are written atomically by [AccountBalanceService].
  Future<TransactionModel> recordRepayment({
    required String userId,
    required TransactionModel repayment,
  }) async {
    try {
      LoggerService.info('Recording loan repayment');

      if (repayment.type != TransactionType.loanRepayment) {
        throw const ValidationException('Not a loan repayment');
      }
      if (repayment.amount <= 0) {
        throw const ValidationException('Repayment amount must be positive');
      }

      final created = await _balanceService.createTransaction(userId, repayment);

      LoggerService.info('Loan repayment recorded successfully');
      return created;
    } catch (e, stackTrace) {
      LoggerService.error('Record repayment error',
          error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException(ErrorMessages.from(e, action: 'record repayment'));
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
