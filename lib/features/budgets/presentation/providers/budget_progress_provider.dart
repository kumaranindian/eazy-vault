import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../data/models/budget_model.dart';
import 'budgets_notifier.dart';

part 'budget_progress_provider.g.dart';

/// A budget joined with this month's actual spend for its category. Spend is
/// computed at read time from `getExpenseTotalsByCategory`, never stored.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.category,
    required this.spent,
  });

  final BudgetModel budget;

  /// `null` if the category was later soft-deleted.
  final CategoryModel? category;
  final double spent;

  double get remaining => budget.amount - spent;

  double get percentage {
    if (budget.amount <= 0) return 0;
    final ratio = spent / budget.amount;
    return ratio < 0 ? 0 : ratio;
  }

  bool get isOverBudget => spent > budget.amount;
}

@riverpod
Future<List<BudgetProgress>> budgetProgress(BudgetProgressRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  final budgetsState = ref.watch(budgetsNotifierProvider);
  final budgets = budgetsState.maybeWhen<List<BudgetModel>>(
    loaded: (budgets) => budgets.where((b) => b.isActive).toList(),
    orElse: () => <BudgetModel>[],
  );

  if (budgets.isEmpty) {
    return [];
  }

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final transactionsRepository = ref.watch(transactionsRepositoryProvider);
  final expenseResult = await transactionsRepository.getExpenseTotalsByCategory(
    user.uid,
    startDate: startOfMonth,
    endDate: endOfMonth,
  );

  final categoriesState = ref.watch(categoriesNotifierProvider);
  final categoriesById = categoriesState.maybeWhen<Map<String, CategoryModel>>(
    loaded: (categories) => {for (final category in categories) category.id: category},
    orElse: () => const {},
  );

  final progress = budgets.map((budget) {
    return BudgetProgress(
      budget: budget,
      category: categoriesById[budget.categoryId],
      spent: expenseResult.totals[budget.categoryId] ?? 0,
    );
  }).toList();

  // Most-over-budget first, so the dashboard summary leads with what needs
  // attention.
  progress.sort((a, b) => b.percentage.compareTo(a.percentage));
  return progress;
}
