import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../../domain/services/account_balance_service.dart';
import '../datasources/transactions_remote_datasource.dart';
import '../models/transaction_model.dart';
import '../../../../core/utils/error_messages.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  TransactionsRepositoryImpl({
    required TransactionsRemoteDataSource remoteDataSource,
    required AccountBalanceService balanceService,
  })  : _remoteDataSource = remoteDataSource,
        _balanceService = balanceService;

  final TransactionsRemoteDataSource _remoteDataSource;
  final AccountBalanceService _balanceService;

  @override
  Future<
      ({
        List<TransactionModel> transactions,
        DocumentSnapshot? lastDocument,
        Failure? failure
      })> getTransactions(
    String userId, {
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final result = await _remoteDataSource.getTransactions(
        userId,
        type: type,
        accountId: accountId,
        categoryId: categoryId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        lastDocument: lastDocument,
      );
      return (
        transactions: result.transactions,
        lastDocument: result.lastDocument,
        failure: null
      );
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (
        transactions: <TransactionModel>[],
        lastDocument: null,
        failure: Failure.serverError(e.message)
      );
    } on NetworkException catch (e) {
      return (
        transactions: <TransactionModel>[],
        lastDocument: null,
        failure: Failure.networkError(e.message)
      );
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (
        transactions: <TransactionModel>[],
        lastDocument: null,
        failure: Failure.unknownError(ErrorMessages.from(e))
      );
    }
  }

  @override
  Future<({TransactionModel? transaction, Failure? failure})> getTransaction(
    String userId,
    String transactionId,
  ) async {
    try {
      final transaction =
          await _remoteDataSource.getTransaction(userId, transactionId);
      return (transaction: transaction, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (transaction: null, failure: Failure.notFoundError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (transaction: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (
        transaction: null,
        failure: Failure.unknownError(ErrorMessages.from(e))
      );
    }
  }

  @override
  Future<({TransactionModel? transaction, Failure? failure})> createTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    try {
      final createdTransaction = await _balanceService.createTransaction(
        userId,
        transaction,
      );

      return (transaction: createdTransaction, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (transaction: null, failure: Failure.notFoundError(e.message));
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (transaction: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (transaction: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (
        transaction: null,
        failure: Failure.unknownError(ErrorMessages.from(e))
      );
    }
  }

  @override
  Future<({TransactionModel? transaction, Failure? failure})> updateTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    try {
      final updatedTransaction = await _balanceService.updateTransaction(
        userId,
        transaction,
      );

      return (transaction: updatedTransaction, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (transaction: null, failure: Failure.notFoundError(e.message));
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (transaction: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (transaction: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (
        transaction: null,
        failure: Failure.unknownError(ErrorMessages.from(e))
      );
    }
  }

  @override
  Future<Failure?> deleteTransaction(
    String userId,
    String transactionId,
    TransactionModel transaction,
  ) async {
    try {
      await _balanceService.deleteTransaction(userId, transactionId);

      return null;
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return Failure.notFoundError(e.message);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return Failure.validationError(e.message);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return Failure.serverError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Stream<List<TransactionModel>> watchTransactions(
    String userId, {
    TransactionType? type,
    int? limit,
  }) {
    return _remoteDataSource.watchTransactions(userId,
        type: type, limit: limit);
  }

  @override
  Future<({double total, Failure? failure})> getTotalByType(
    String userId,
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final total = await _remoteDataSource.getTotalByType(
        userId,
        type,
        startDate: startDate,
        endDate: endDate,
      );
      return (total: total, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (total: 0.0, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (total: 0.0, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<
      ({
        Map<String, ({double income, double expense})> totals,
        Failure? failure
      })> getTotalsByAccount(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final totals = await _remoteDataSource.getTotalsByAccount(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      return (totals: totals, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (
        totals: <String, ({double income, double expense})>{},
        failure: Failure.serverError(e.message)
      );
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (
        totals: <String, ({double income, double expense})>{},
        failure: Failure.unknownError(ErrorMessages.from(e))
      );
    }
  }

  @override
  Future<({Map<String, double> totals, Failure? failure})> getExpenseTotalsByCategory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final totals = await _remoteDataSource.getExpenseTotalsByCategory(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      return (totals: totals, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (totals: <String, double>{}, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (totals: <String, double>{}, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<
      ({
        Map<DateTime, ({double income, double expense})> totals,
        Failure? failure
      })> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final totals = await _remoteDataSource.getMonthlyTotals(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      return (totals: totals, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (
        totals: <DateTime, ({double income, double expense})>{},
        failure: Failure.serverError(e.message),
      );
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (
        totals: <DateTime, ({double income, double expense})>{},
        failure: Failure.unknownError(ErrorMessages.from(e)),
      );
    }
  }
}
