import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../models/recurring_transaction_model.dart';

abstract class RecurringTransactionsRemoteDataSource {
  Future<List<RecurringTransactionModel>> getRecurringTransactions(String userId);
  Future<RecurringTransactionModel> getRecurringTransaction(String userId, String ruleId);
  Future<RecurringTransactionModel> createRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  );
  Future<RecurringTransactionModel> updateRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  );
  Future<void> deleteRecurringTransaction(String userId, String ruleId);
  Stream<List<RecurringTransactionModel>> watchRecurringTransactions(String userId);
}

class RecurringTransactionsRemoteDataSourceImpl implements RecurringTransactionsRemoteDataSource {
  RecurringTransactionsRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.recurringTransactionsCollection);
  }

  @override
  Future<List<RecurringTransactionModel>> getRecurringTransactions(String userId) async {
    try {
      LoggerService.info('Fetching recurring transactions for user: $userId');

      final querySnapshot = await _collection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy(AppConstants.createdAtField, descending: false)
          .get();

      final rules = querySnapshot.docs
          .map((doc) => RecurringTransactionModel.fromFirestore(doc))
          .toList();

      LoggerService.info('Fetched ${rules.length} recurring transactions');
      return rules;
    } catch (e, stackTrace) {
      LoggerService.error('Get recurring transactions error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch recurring transactions: ${e.toString()}');
    }
  }

  @override
  Future<RecurringTransactionModel> getRecurringTransaction(String userId, String ruleId) async {
    try {
      LoggerService.info('Fetching recurring transaction: $ruleId');

      final doc = await _collection(userId).doc(ruleId).get();

      if (!doc.exists) {
        throw const NotFoundException('Recurring transaction not found');
      }

      return RecurringTransactionModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      LoggerService.error('Get recurring transaction error', error: e, stackTrace: stackTrace);
      if (e is NotFoundException) rethrow;
      throw ServerException('Failed to fetch recurring transaction: ${e.toString()}');
    }
  }

  @override
  Future<RecurringTransactionModel> createRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  ) async {
    try {
      LoggerService.info('Creating recurring transaction for category: ${rule.categoryId}');

      final docRef = _collection(userId).doc();
      final ruleWithId = rule.copyWith(id: docRef.id);

      await docRef.set(ruleWithId.toFirestore());

      LoggerService.info('Recurring transaction created: ${docRef.id}');
      return ruleWithId;
    } catch (e, stackTrace) {
      LoggerService.error('Create recurring transaction error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to create recurring transaction: ${e.toString()}');
    }
  }

  @override
  Future<RecurringTransactionModel> updateRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  ) async {
    try {
      LoggerService.info('Updating recurring transaction: ${rule.id}');

      final updatedRule = rule.copyWith(updatedAt: DateTime.now());

      await _collection(userId).doc(rule.id).update(updatedRule.toFirestore());

      LoggerService.info('Recurring transaction updated: ${rule.id}');
      return updatedRule;
    } catch (e, stackTrace) {
      LoggerService.error('Update recurring transaction error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update recurring transaction: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteRecurringTransaction(String userId, String ruleId) async {
    try {
      LoggerService.info('Deleting recurring transaction: $ruleId');

      await _collection(userId).doc(ruleId).update({
        AppConstants.isDeletedField: true,
        AppConstants.updatedAtField: Timestamp.now(),
      });

      LoggerService.info('Recurring transaction deleted: $ruleId');
    } catch (e, stackTrace) {
      LoggerService.error('Delete recurring transaction error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to delete recurring transaction: ${e.toString()}');
    }
  }

  @override
  Stream<List<RecurringTransactionModel>> watchRecurringTransactions(String userId) {
    try {
      LoggerService.info('Watching recurring transactions for user: $userId');

      return _collection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy(AppConstants.createdAtField, descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => RecurringTransactionModel.fromFirestore(doc))
            .toList();
      });
    } catch (e, stackTrace) {
      LoggerService.error('Watch recurring transactions error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to watch recurring transactions: ${e.toString()}');
    }
  }
}
