import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/repositories/budgets_repository.dart';
import '../datasources/budgets_remote_datasource.dart';
import '../models/budget_model.dart';

class BudgetsRepositoryImpl implements BudgetsRepository {
  BudgetsRepositoryImpl({required BudgetsRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final BudgetsRemoteDataSource _remoteDataSource;

  @override
  Future<({List<BudgetModel> budgets, Failure? failure})> getBudgets(String userId) async {
    try {
      final budgets = await _remoteDataSource.getBudgets(userId);
      return (budgets: budgets, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (budgets: <BudgetModel>[], failure: Failure.serverError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (budgets: <BudgetModel>[], failure: Failure.networkError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (budgets: <BudgetModel>[], failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<({BudgetModel? budget, Failure? failure})> getBudget(
    String userId,
    String budgetId,
  ) async {
    try {
      final budget = await _remoteDataSource.getBudget(userId, budgetId);
      return (budget: budget, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (budget: null, failure: Failure.notFoundError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (budget: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (budget: null, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<({BudgetModel? budget, Failure? failure})> createBudget(
    String userId,
    BudgetModel budget,
  ) async {
    try {
      final createdBudget = await _remoteDataSource.createBudget(userId, budget);
      return (budget: createdBudget, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (budget: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (budget: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (budget: null, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<({BudgetModel? budget, Failure? failure})> updateBudget(
    String userId,
    BudgetModel budget,
  ) async {
    try {
      final updatedBudget = await _remoteDataSource.updateBudget(userId, budget);
      return (budget: updatedBudget, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (budget: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (budget: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (budget: null, failure: Failure.unknownError(e.toString()));
    }
  }

  @override
  Future<Failure?> deleteBudget(String userId, String budgetId) async {
    try {
      await _remoteDataSource.deleteBudget(userId, budgetId);
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
  Stream<List<BudgetModel>> watchBudgets(String userId) {
    return _remoteDataSource.watchBudgets(userId);
  }
}
