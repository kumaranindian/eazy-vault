import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/repositories/categories_repository.dart';
import '../datasources/categories_remote_datasource.dart';
import '../models/category_model.dart';
import '../../../../core/utils/error_messages.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  CategoriesRepositoryImpl({required CategoriesRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final CategoriesRemoteDataSource _remoteDataSource;

  @override
  Future<({List<CategoryModel> categories, Failure? failure})> getCategories(
    String userId, {
    CategoryType? type,
  }) async {
    try {
      final categories = await _remoteDataSource.getCategories(userId, type: type);
      return (categories: categories, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (categories: <CategoryModel>[], failure: Failure.serverError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (categories: <CategoryModel>[], failure: Failure.networkError(e.message));
    } catch (e) {
      LoggerService.error('Unknown error', error: e);
      return (categories: <CategoryModel>[], failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({CategoryModel? category, Failure? failure})> getCategory(
    String userId,
    String categoryId,
  ) async {
    try {
      final category = await _remoteDataSource.getCategory(userId, categoryId);
      return (category: category, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (category: null, failure: Failure.notFoundError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (category: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (category: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({CategoryModel? category, Failure? failure})> createCategory(
    String userId,
    CategoryModel category,
  ) async {
    try {
      final createdCategory = await _remoteDataSource.createCategory(userId, category);
      return (category: createdCategory, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (category: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (category: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (category: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({CategoryModel? category, Failure? failure})> updateCategory(
    String userId,
    CategoryModel category,
  ) async {
    try {
      final updatedCategory = await _remoteDataSource.updateCategory(userId, category);
      return (category: updatedCategory, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (category: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (category: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (category: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<Failure?> deleteCategory(String userId, String categoryId) async {
    try {
      await _remoteDataSource.deleteCategory(userId, categoryId);
      return null;
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
  Future<Failure?> seedDefaultCategories(String userId) async {
    try {
      await _remoteDataSource.seedDefaultCategories(userId);
      return null;
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return Failure.serverError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Stream<List<CategoryModel>> watchCategories(String userId, {CategoryType? type}) {
    return _remoteDataSource.watchCategories(userId, type: type);
  }
}
