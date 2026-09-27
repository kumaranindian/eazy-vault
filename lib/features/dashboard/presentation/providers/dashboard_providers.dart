import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../data/models/account_financials.dart';

part 'dashboard_providers.g.dart';

class MonthlyStats {
  const MonthlyStats({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  double get netSavings => income - expense;
}

@riverpod
Future<MonthlyStats> currentMonthStats(CurrentMonthStatsRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const MonthlyStats(income: 0, expense: 0);
  }

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final repository = ref.watch(transactionsRepositoryProvider);

  final incomeResult = await repository.getTotalByType(
    user.uid,
    TransactionType.income,
    startDate: startOfMonth,
    endDate: endOfMonth,
  );

  final expenseResult = await repository.getTotalByType(
    user.uid,
    TransactionType.expense,
    startDate: startOfMonth,
    endDate: endOfMonth,
  );

  return MonthlyStats(
    income: incomeResult.total,
    expense: expenseResult.total,
  );
}

@riverpod
Future<Map<String, double>> categoryExpenses(CategoryExpensesRef ref) async {
  // TODO: Implement category-wise expense breakdown when needed
  await Future.delayed(const Duration(milliseconds: 500));
  
  return {};
}

@riverpod
Future<Map<String, AccountFinancials>> accountFinancials(AccountFinancialsRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return {};
  }

  final accountsState = ref.watch(accountsNotifierProvider);
  
  final accounts = accountsState.maybeWhen<List<AccountModel>>(
    loaded: (accounts) => accounts,
    orElse: () => <AccountModel>[],
  );

  if (accounts.isEmpty) {
    return {};
  }

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final repository = ref.watch(transactionsRepositoryProvider);

  final result = await repository.getTotalsByAccount(
    user.uid,
    startDate: startOfMonth,
    endDate: endOfMonth,
  );

  final accountFinancialsMap = <String, AccountFinancials>{};

  for (final account in accounts) {
    final totals = result.totals[account.id] ?? (income: 0.0, expense: 0.0);
    
    accountFinancialsMap[account.id] = AccountFinancials(
      openingBalance: account.openingBalance,
      income: totals.income,
      expense: totals.expense,
      balance: account.currentBalance,
    );
  }

  return accountFinancialsMap;
}
