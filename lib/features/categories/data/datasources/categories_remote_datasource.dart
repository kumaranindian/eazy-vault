import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/enums/category_type.dart';
import '../models/category_model.dart';
import '../models/default_categories.dart';
import '../../../../core/utils/error_messages.dart';

abstract class CategoriesRemoteDataSource {
  Future<List<CategoryModel>> getCategories(String userId, {CategoryType? type});
  Future<CategoryModel> getCategory(String userId, String categoryId);
  Future<CategoryModel> createCategory(String userId, CategoryModel category);
  Future<CategoryModel> updateCategory(String userId, CategoryModel category);
  Future<void> deleteCategory(String userId, String categoryId);
  Future<void> seedDefaultCategories(String userId);
  Stream<List<CategoryModel>> watchCategories(String userId, {CategoryType? type});
}

class CategoriesRemoteDataSourceImpl implements CategoriesRemoteDataSource {
  CategoriesRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _categoriesCollection(String userId) {
    return _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.categoriesCollection);
  }

  @override
  Future<List<CategoryModel>> getCategories(
    String userId, {
    CategoryType? type,
  }) async {
    try {
      LoggerService.info('Fetching categories for user: $userId');

      var query = _categoriesCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      final querySnapshot = await query
          .orderBy(AppConstants.createdAtField, descending: false)
          .get();

      final categories = querySnapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();

      LoggerService.info('Fetched ${categories.length} categories');
      return categories;
    } catch (e, stackTrace) {
      LoggerService.error('Get categories error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'load categories'));
    }
  }

  @override
  Future<CategoryModel> getCategory(String userId, String categoryId) async {
    try {
      LoggerService.info('Fetching category: $categoryId');

      final doc = await _categoriesCollection(userId).doc(categoryId).get();

      if (!doc.exists) {
        throw const NotFoundException('Category not found');
      }

      return CategoryModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      LoggerService.error('Get category error', error: e, stackTrace: stackTrace);
      if (e is NotFoundException) rethrow;
      throw ServerException(ErrorMessages.from(e, action: 'load category'));
    }
  }

  @override
  Future<CategoryModel> createCategory(String userId, CategoryModel category) async {
    try {
      LoggerService.info('Creating category: ${category.name}');

      final docRef = _categoriesCollection(userId).doc();
      final categoryWithId = category.copyWith(id: docRef.id);

      await docRef.set(categoryWithId.toFirestore());

      LoggerService.info('Category created: ${docRef.id}');
      return categoryWithId;
    } catch (e, stackTrace) {
      LoggerService.error('Create category error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'create category'));
    }
  }

  @override
  Future<CategoryModel> updateCategory(String userId, CategoryModel category) async {
    try {
      LoggerService.info('Updating category: ${category.id}');

      final updatedCategory = category.copyWith(updatedAt: DateTime.now());

      await _categoriesCollection(userId)
          .doc(category.id)
          .update(updatedCategory.toFirestore());

      LoggerService.info('Category updated: ${category.id}');
      return updatedCategory;
    } catch (e, stackTrace) {
      LoggerService.error('Update category error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'update category'));
    }
  }

  /// Soft-deletes a category. Categories still referenced by a (non-deleted)
  /// transaction can't be deleted, mirroring the same guard
  /// `AccountsRemoteDataSourceImpl.deleteAccount` uses for accounts.
  @override
  Future<void> deleteCategory(String userId, String categoryId) async {
    try {
      LoggerService.info('Deleting category: $categoryId');

      final inUse = await _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection)
          .where('categoryId', isEqualTo: categoryId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .limit(1)
          .get();

      if (inUse.docs.isNotEmpty) {
        throw const ValidationException(
          'This category is used by existing transactions and cannot be deleted.',
        );
      }

      await _categoriesCollection(userId).doc(categoryId).update({
        AppConstants.isDeletedField: true,
        AppConstants.updatedAtField: Timestamp.now(),
      });

      LoggerService.info('Category deleted: $categoryId');
    } catch (e, stackTrace) {
      LoggerService.error('Delete category error', error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException(ErrorMessages.from(e, action: 'delete category'));
    }
  }

  @override
  Future<void> seedDefaultCategories(String userId) async {
    try {
      LoggerService.info('Seeding default categories for user: $userId');

      final existingCategories = await getCategories(userId);
      if (existingCategories.isNotEmpty) {
        LoggerService.info('Categories already exist, skipping seed');
        return;
      }

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final defaultCategory in DefaultCategories.allCategories) {
        final docRef = _categoriesCollection(userId).doc();
        final category = CategoryModel(
          id: docRef.id,
          name: defaultCategory.name,
          type: defaultCategory.type,
          color: defaultCategory.color,
          icon: defaultCategory.icon,
          description: defaultCategory.description,
          isDefault: true,
          isActive: true,
          createdAt: now,
          updatedAt: now,
          createdBy: userId,
        );

        batch.set(docRef, category.toFirestore());
      }

      await batch.commit();
      LoggerService.info('Default categories seeded successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Seed categories error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'add the default categories'));
    }
  }

  @override
  Stream<List<CategoryModel>> watchCategories(
    String userId, {
    CategoryType? type,
  }) {
    try {
      LoggerService.info('Watching categories for user: $userId');

      var query = _categoriesCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      return query
          .orderBy(AppConstants.createdAtField, descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList();
      });
    } catch (e, stackTrace) {
      LoggerService.error('Watch categories error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'load categories'));
    }
  }
}
