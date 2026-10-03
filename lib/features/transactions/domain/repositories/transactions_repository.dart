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

  Future<({Map<String, double> totals, Failure? failure})> getExpenseTotalsByCategory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<({Map<DateTime, ({double income, double expense})> totals, Failure? failure})> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Income transactions whose *effective* reporting period falls in
  /// [startPeriod]..[endPeriod] (every income transaction when both are
  /// null). See `TransactionModelExtensions.effectiveIncomePeriod`.
  Future<({List<TransactionModel> transactions, Failure? failure})> getIncomeTransactions(
    String userId, {
    DateTime? startPeriod,
    DateTime? endPeriod,
  });

  /// Every non-deleted transaction affecting [accountId]'s balance, dated on
  /// or before [endDate], sorted ascending by date — for account statements.
  Future<({List<TransactionModel> transactions, Failure? failure})> getAccountHistory(
    String userId,
    String accountId, {
    DateTime? endDate,
  });

  /// Appends [attachmentUrl] to [transactionId]'s attachments. Allowed on
  /// any transaction type — attachments don't affect balances.
  Future<Failure?> addAttachment(String userId, String transactionId, String attachmentUrl);

  /// Removes [attachmentUrl] from [transactionId]'s attachments.
  Future<Failure?> removeAttachment(String userId, String transactionId, String attachmentUrl);
}
