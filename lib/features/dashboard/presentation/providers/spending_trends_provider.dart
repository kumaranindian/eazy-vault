import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dashboard_providers.dart';

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

@riverpod
Future<List<MonthlyTrendStats>> last6MonthsStats(Last6MonthsStatsRef ref) async {
  final now = DateTime.now();
  final stats = <MonthlyTrendStats>[];

  try {
    // For now, use current month stats as placeholder
    // TODO: Implement actual monthly stats fetching
    final monthlyStats = await ref.watch(
      currentMonthStatsProvider.future,
    );

    final totalIncome = monthlyStats.income;
    final totalExpense = monthlyStats.expense;

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);

      // Distribute evenly for demo, with safety checks
      final monthIncome = totalIncome > 0 ? totalIncome / 6 : 0.0;
      final monthExpense = totalExpense > 0 ? totalExpense / 6 : 0.0;

      stats.add(MonthlyTrendStats(
        month: month,
        income: monthIncome.isFinite ? monthIncome : 0.0,
        expense: monthExpense.isFinite ? monthExpense : 0.0,
      ));
    }
  } catch (e) {
    // Return empty stats on error
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      stats.add(MonthlyTrendStats(
        month: month,
        income: 0.0,
        expense: 0.0,
      ));
    }
  }

  return stats;
}
