import '../../../../core/models/failure.dart';
import '../../data/models/budget_model.dart';

abstract class BudgetsRepository {
  Future<({List<BudgetModel> budgets, Failure? failure})> getBudgets(String userId);

  Future<({BudgetModel? budget, Failure? failure})> getBudget(
    String userId,
    String budgetId,
  );

  Future<({BudgetModel? budget, Failure? failure})> createBudget(
    String userId,
    BudgetModel budget,
  );

  Future<({BudgetModel? budget, Failure? failure})> updateBudget(
    String userId,
    BudgetModel budget,
  );

  Future<Failure?> deleteBudget(String userId, String budgetId);

  Stream<List<BudgetModel>> watchBudgets(String userId);
}
