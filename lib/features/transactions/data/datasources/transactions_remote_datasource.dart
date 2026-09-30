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

  /// Expense totals per category id for transactions dated in
  /// [startDate]..[endDate]. Income and transfer/loan transactions (which use
  /// the sentinel `'transfer'`/`'loan'` category ids) are excluded.
  Future<Map<String, double>> getExpenseTotalsByCategory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Income/expense totals per calendar month (keyed by the first day of the
  /// month, local time) for transactions dated in [startDate]..[endDate].
  Future<Map<DateTime, ({double income, double expense})>> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
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

  @override
  Future<Map<String, double>> getExpenseTotalsByCategory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      LoggerService.info('Calculating expense totals by category');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: TransactionType.expense.name);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();

      final categoryTotals = <String, double>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final categoryId = data['categoryId'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;

        if (categoryId != null) {
          categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) + amount;
        }
      }

      LoggerService.info('Calculated expense totals for ${categoryTotals.length} categories');
      return categoryTotals;
    } catch (e, stackTrace) {
      LoggerService.error('Get expense totals by category error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to calculate expense totals by category: ${e.toString()}');
    }
  }

  @override
  Future<Map<DateTime, ({double income, double expense})>> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final totals = <DateTime, ({double income, double expense})>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;

        final month = DateTime(date.year, date.month);
        final current = totals[month] ?? (income: 0.0, expense: 0.0);
        if (type == TransactionType.income.name) {
          totals[month] = (income: current.income + amount, expense: current.expense);
        } else if (type == TransactionType.expense.name) {
          totals[month] = (income: current.income, expense: current.expense + amount);
        }
      }
      return totals;
    } catch (e, stackTrace) {
      LoggerService.error('Get monthly totals error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to calculate monthly totals: ${e.toString()}');
    }
  }
}
