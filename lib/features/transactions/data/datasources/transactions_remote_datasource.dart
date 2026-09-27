import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/enums/transaction_type.dart';
import '../models/transaction_model.dart';

abstract class TransactionsRemoteDataSource {
  Future<({List<TransactionModel> transactions, DocumentSnapshot? lastDocument})> getTransactions(
    String userId, {
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    DocumentSnapshot? lastDocument,
  });

  Future<TransactionModel> getTransaction(String userId, String transactionId);
  
  Future<TransactionModel> createTransaction(
    String userId,
    TransactionModel transaction,
  );
  
  Future<TransactionModel> updateTransaction(
    String userId,
    TransactionModel transaction,
  );
  
  Future<void> deleteTransaction(String userId, String transactionId);
  
  Stream<List<TransactionModel>> watchTransactions(
    String userId, {
    TransactionType? type,
    int? limit,
  });

  Future<double> getTotalByType(
    String userId,
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, ({double income, double expense})>> getTotalsByAccount(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });
}

class TransactionsRemoteDataSourceImpl implements TransactionsRemoteDataSource {
  TransactionsRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _transactionsCollection(String userId) {
    return _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.transactionsCollection);
  }

  @override
  Future<({List<TransactionModel> transactions, DocumentSnapshot? lastDocument})> getTransactions(
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
      LoggerService.info('Fetching transactions for user: $userId');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (accountId != null) {
        query = query.where('accountId', isEqualTo: accountId);
      }

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('date', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      if (limit != null) {
        query = query.limit(limit);
      } else {
        query = query.limit(AppConfig.defaultPageSize);
      }

      final querySnapshot = await query.get();

      final transactions = querySnapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      final lastDoc = querySnapshot.docs.isNotEmpty 
          ? querySnapshot.docs.last 
          : null;

      LoggerService.info('Fetched ${transactions.length} transactions');
      return (transactions: transactions, lastDocument: lastDoc);
    } catch (e, stackTrace) {
      LoggerService.error('Get transactions error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch transactions: ${e.toString()}');
    }
  }

  @override
  Future<TransactionModel> getTransaction(String userId, String transactionId) async {
    try {
      LoggerService.info('Fetching transaction: $transactionId');

      final doc = await _transactionsCollection(userId).doc(transactionId).get();

      if (!doc.exists) {
        throw const NotFoundException('Transaction not found');
      }

      return TransactionModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      LoggerService.error('Get transaction error', error: e, stackTrace: stackTrace);
      if (e is NotFoundException) rethrow;
      throw ServerException('Failed to fetch transaction: ${e.toString()}');
    }
  }

  @override
  Future<TransactionModel> createTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    try {
      LoggerService.info('Creating transaction: ${transaction.type.name}');

      final docRef = _transactionsCollection(userId).doc();
      final transactionWithId = transaction.copyWith(id: docRef.id);

      await docRef.set(transactionWithId.toFirestore());

      LoggerService.info('Transaction created: ${docRef.id}');
      return transactionWithId;
    } catch (e, stackTrace) {
      LoggerService.error('Create transaction error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to create transaction: ${e.toString()}');
    }
  }

  @override
  Future<TransactionModel> updateTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    try {
      LoggerService.info('Updating transaction: ${transaction.id}');

      final updatedTransaction = transaction.copyWith(updatedAt: DateTime.now());

      await _transactionsCollection(userId)
          .doc(transaction.id)
          .update(updatedTransaction.toFirestore());

      LoggerService.info('Transaction updated: ${transaction.id}');
      return updatedTransaction;
    } catch (e, stackTrace) {
      LoggerService.error('Update transaction error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update transaction: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteTransaction(String userId, String transactionId) async {
    try {
      LoggerService.info('Deleting transaction: $transactionId');

      await _transactionsCollection(userId).doc(transactionId).update({
        AppConstants.isDeletedField: true,
        AppConstants.updatedAtField: Timestamp.now(),
      });

      LoggerService.info('Transaction deleted: $transactionId');
    } catch (e, stackTrace) {
      LoggerService.error('Delete transaction error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to delete transaction: ${e.toString()}');
    }
  }

  @override
  Stream<List<TransactionModel>> watchTransactions(
    String userId, {
    TransactionType? type,
    int? limit,
  }) {
    try {
      LoggerService.info('Watching transactions for user: $userId');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      query = query
          .orderBy('date', descending: true)
          .limit(limit ?? AppConfig.defaultPageSize);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList();
      });
    } catch (e, stackTrace) {
      LoggerService.error('Watch transactions error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to watch transactions: ${e.toString()}');
    }
  }

  @override
  Future<double> getTotalByType(
    String userId,
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      LoggerService.info('Calculating total for type: ${type.name}');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: type.name);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();

      final total = querySnapshot.docs.fold<double>(
        0,
        (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
      );

      LoggerService.info('Total for ${type.name}: $total');
      return total;
    } catch (e, stackTrace) {
      LoggerService.error('Get total error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to calculate total: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, ({double income, double expense})>> getTotalsByAccount(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      LoggerService.info('Calculating totals by account');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();

      final accountTotals = <String, ({double income, double expense})>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final accountId = data['accountId'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final type = data['type'] as String?;

        if (accountId != null && type != null) {
          final current = accountTotals[accountId] ?? (income: 0.0, expense: 0.0);
          
          if (type == TransactionType.income.name) {
            accountTotals[accountId] = (income: current.income + amount, expense: current.expense);
          } else if (type == TransactionType.expense.name) {
            accountTotals[accountId] = (income: current.income, expense: current.expense + amount);
          }
        }
      }

      LoggerService.info('Calculated totals for ${accountTotals.length} accounts');
      return accountTotals;
    } catch (e, stackTrace) {
      LoggerService.error('Get totals by account error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to calculate totals by account: ${e.toString()}');
    }
  }
}
