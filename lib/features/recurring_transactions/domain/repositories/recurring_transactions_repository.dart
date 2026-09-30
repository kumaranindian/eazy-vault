import '../../../../core/models/failure.dart';
import '../../data/models/recurring_transaction_model.dart';

abstract class RecurringTransactionsRepository {
  Future<({List<RecurringTransactionModel> rules, Failure? failure})> getRecurringTransactions(
    String userId,
  );

  Future<({RecurringTransactionModel? rule, Failure? failure})> getRecurringTransaction(
    String userId,
    String ruleId,
  );

  Future<({RecurringTransactionModel? rule, Failure? failure})> createRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  );

  Future<({RecurringTransactionModel? rule, Failure? failure})> updateRecurringTransaction(
    String userId,
    RecurringTransactionModel rule,
  );

  Future<Failure?> deleteRecurringTransaction(String userId, String ruleId);

  Stream<List<RecurringTransactionModel>> watchRecurringTransactions(String userId);
}
