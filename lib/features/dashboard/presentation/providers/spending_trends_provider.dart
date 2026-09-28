import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';

part 'spending_trends_provider.g.dart';

class MonthlyTrendStats {
  final DateTime month;
  final double income;
  final double expense;

  MonthlyTrendStats({
    required this.month,
    required this.income,
    required this.expense,
  });
}

/// Income and expense totals for the current month and the five before it,
/// oldest first. Months without transactions are reported as zero.
@riverpod
Future<List<MonthlyTrendStats>> last6MonthsStats(Last6MonthsStatsRef ref) async {
  final now = DateTime.now();
  final firstMonth = DateTime(now.year, now.month - 5);
  final months = [
    for (var i = 0; i < 6; i++) DateTime(firstMonth.year, firstMonth.month + i),
  ];

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [
      for (final month in months)
        MonthlyTrendStats(month: month, income: 0, expense: 0),
    ];
  }

  final result = await ref.watch(transactionsRepositoryProvider).getMonthlyTotals(
        user.uid,
        startDate: firstMonth,
        endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
      );

  if (result.failure != null) {
    throw Exception(result.failure!.message);
  }

  return [
    for (final month in months)
      MonthlyTrendStats(
        month: month,
        income: result.totals[month]?.income ?? 0,
        expense: result.totals[month]?.expense ?? 0,
      ),
  ];
}
