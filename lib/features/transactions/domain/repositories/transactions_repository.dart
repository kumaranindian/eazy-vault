import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/failure.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';

abstract class TransactionsRepository {
  Future<({List<TransactionModel> transactions, DocumentSnapshot? lastDocument, Failure? failure})> getTransactions(
    String userId, {
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    DocumentSnapshot? lastDocument,
  });

  Future<({TransactionModel? transaction, Failure? failure})> getTransaction(
    String userId,
    String transactionId,
  );

  Future<({TransactionModel? transaction, Failure? failure})> createTransaction(
    String userId,
    TransactionModel transaction,
  );

  /// Updates an income/expense transaction. The stored version is used to
  /// compute the balance change; transfers and loans can't be edited.
  Future<({TransactionModel? transaction, Failure? failure})> updateTransaction(
    String userId,
    TransactionModel transaction,
  );

  Future<Failure?> deleteTransaction(
    String userId,
    String transactionId,
    TransactionModel transaction,
  );

  Stream<List<TransactionModel>> watchTransactions(
    String userId, {
    TransactionType? type,
    int? limit,
  });

  Future<({double total, Failure? failure})> getTotalByType(
    String userId,
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<({Map<String, ({double income, double expense})> totals, Failure? failure})> getTotalsByAccount(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<({Map<DateTime, ({double income, double expense})> totals, Failure? failure})> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  });
}
