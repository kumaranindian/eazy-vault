import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/repositories/recurring_transactions_repository.dart';
import '../datasources/recurring_transactions_remote_datasource.dart';
import '../models/recurring_transaction_model.dart';

class RecurringTransactionsRepositoryImpl implements RecurringTransactionsRepository {
  RecurringTransactionsRepositoryImpl({
    required RecurringTransactionsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final RecurringTransactionsRemoteDataSource _remoteDataSource;

  @override
  Future<({List<RecurringTransactionModel> rules, Failure? failure})> getRecurringTransactions(
    String userId,
  ) async {
    try {
      final rules = await _remoteDataSource.getRecurringTransactions(userId);
      return (rules: rules, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (rules: <RecurringTransactionModel>[], failure: Failure.serverError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (rules: <RecurringTransactionModel>[], failure: Failure.networkError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (rules: <RecurringTransactionModel>[], failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<({RecurringTransactionModel? rule, Failure? failure})> getRecurringTransaction(
    String userId,
    String ruleId,
  ) async {
    try {
      final rule = await _remoteDataSource.getRecurringTransaction(userId, ruleId);
      return (rule: rule, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (rule: null, failure: Failure.notFoundError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (rule: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (rule: null, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<({RecurringTransactionModel? rule, Failure? failure})> createRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  ) async {
    try {
      final created = await _remoteDataSource.createRecurringTransaction(userId, rule);
      return (rule: created, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (rule: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (rule: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (rule: null, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<({RecurringTransactionModel? rule, Failure? failure})> updateRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  ) async {
    try {
      final updated = await _remoteDataSource.updateRecurringTransaction(userId, rule);
      return (rule: updated, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (rule: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (rule: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (rule: null, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<Failure?> deleteRecurringTransaction(String userId, String ruleId) async {
    try {
      await _remoteDataSource.deleteRecurringTransaction(userId, ruleId);
      return null;
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return Failure.serverError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(e.toString());
    }
  }

  @override
  Stream<List<RecurringTransactionModel>> watchRecurringTransactions(String userId) {
    return _remoteDataSource.watchRecurringTransactions(userId);
  }
}
