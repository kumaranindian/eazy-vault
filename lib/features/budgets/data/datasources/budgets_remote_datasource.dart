import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../models/budget_model.dart';

abstract class BudgetsRemoteDataSource {
  Future<List<BudgetModel>> getBudgets(String userId);
  Future<BudgetModel> getBudget(String userId, String budgetId);
  Future<BudgetModel> createBudget(String userId, BudgetModel budget);
  Future<BudgetModel> updateBudget(String userId, BudgetModel budget);
  Future<void> deleteBudget(String userId, String budgetId);
  Stream<List<BudgetModel>> watchBudgets(String userId);
}

class BudgetsRemoteDataSourceImpl implements BudgetsRemoteDataSource {
  BudgetsRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _budgetsCollection(String userId) {
    return _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.budgetsCollection);
  }

  @override
  Future<List<BudgetModel>> getBudgets(String userId) async {
    try {
      LoggerService.info('Fetching budgets for user: $userId');

      final querySnapshot = await _budgetsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy(AppConstants.createdAtField, descending: false)
          .get();

      final budgets = querySnapshot.docs
          .map((doc) => BudgetModel.fromFirestore(doc))
          .toList();

      LoggerService.info('Fetched ${budgets.length} budgets');
      return budgets;
    } catch (e, stackTrace) {
      LoggerService.error('Get budgets error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch budgets: ${e.toString()}');
    }
  }

  @override
  Future<BudgetModel> getBudget(String userId, String budgetId) async {
    try {
      LoggerService.info('Fetching budget: $budgetId');

      final doc = await _budgetsCollection(userId).doc(budgetId).get();

      if (!doc.exists) {
        throw const NotFoundException('Budget not found');
      }

      return BudgetModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      LoggerService.error('Get budget error', error: e, stackTrace: stackTrace);
      if (e is NotFoundException) rethrow;
      throw ServerException('Failed to fetch budget: ${e.toString()}');
    }
  }

  @override
  Future<BudgetModel> createBudget(String userId, BudgetModel budget) async {
    try {
      LoggerService.info('Creating budget for category: ${budget.categoryId}');

      final docRef = _budgetsCollection(userId).doc();
      final budgetWithId = budget.copyWith(id: docRef.id);

      await docRef.set(budgetWithId.toFirestore());

      LoggerService.info('Budget created: ${docRef.id}');
      return budgetWithId;
    } catch (e, stackTrace) {
      LoggerService.error('Create budget error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to create budget: ${e.toString()}');
    }
  }

  @override
  Future<BudgetModel> updateBudget(String userId, BudgetModel budget) async {
    try {
      LoggerService.info('Updating budget: ${budget.id}');

      final updatedBudget = budget.copyWith(updatedAt: DateTime.now());

      await _budgetsCollection(userId)
          .doc(budget.id)
          .update(updatedBudget.toFirestore());

      LoggerService.info('Budget updated: ${budget.id}');
      return updatedBudget;
    } catch (e, stackTrace) {
      LoggerService.error('Update budget error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update budget: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteBudget(String userId, String budgetId) async {
    try {
      LoggerService.info('Deleting budget: $budgetId');

      await _budgetsCollection(userId).doc(budgetId).update({
        AppConstants.isDeletedField: true,
        AppConstants.updatedAtField: Timestamp.now(),
      });

      LoggerService.info('Budget deleted: $budgetId');
    } catch (e, stackTrace) {
      LoggerService.error('Delete budget error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to delete budget: ${e.toString()}');
    }
  }

  @override
  Stream<List<BudgetModel>> watchBudgets(String userId) {
    try {
      LoggerService.info('Watching budgets for user: $userId');

      return _budgetsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy(AppConstants.createdAtField, descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();
      });
    } catch (e, stackTrace) {
      LoggerService.error('Watch budgets error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to watch budgets: ${e.toString()}');
    }
  }
}
