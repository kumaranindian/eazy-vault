import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../providers/spending_trends_provider.dart';

class SpendingTrendsChart extends ConsumerWidget {
  const SpendingTrendsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyStatsAsync = ref.watch(last6MonthsStatsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Spending Trends',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Last 6 Months',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chart
            monthlyStatsAsync.when(
              data: (stats) {
                if (stats.isEmpty) {
                  return _EmptyState();
                }

                return Column(
                  children: [
                    // Legend
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _LegendItem(
                          color: Colors.green,
                          label: 'Income',
                        ),
                        _LegendItem(
                          color: Colors.red,
                          label: 'Expense',
                        ),
                        _LegendItem(
                          color: Colors.blue,
                          label: 'Net',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Line Chart
                    // Width follows the card; taller where there's room.
                    SizedBox(
                      height: context.isMobile || context.isCompactHeight ? 200 : 260,
                      child: LineChart(
                        _buildLineChartData(context, stats),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load trends',
                        style: TextStyle(color: context.colorScheme.error),
                      ),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(last6MonthsStatsProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData(
    BuildContext context,
    List<MonthlyTrendStats> stats,
  ) {
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final netSpots = <FlSpot>[];

    for (int i = 0; i < stats.length; i++) {
      final stat = stats[i];
      incomeSpots.add(FlSpot(i.toDouble(), stat.income));
      expenseSpots.add(FlSpot(i.toDouble(), stat.expense));
      netSpots.add(FlSpot(i.toDouble(), stat.income - stat.expense));
    }

    // Find max value for Y axis with safety checks
    final maxIncome = stats.isEmpty ? 0.0 : stats.map((s) => s.income).reduce((a, b) => a > b ? a : b);
    final maxExpense = stats.isEmpty ? 0.0 : stats.map((s) => s.expense).reduce((a, b) => a > b ? a : b);
    final maxValue = (maxIncome > maxExpense ? maxIncome : maxExpense);
    final minNet = stats.isEmpty ? 0.0 : stats.map((s) => s.income - s.expense).reduce((a, b) => a < b ? a : b);

    // Ensure we have a valid interval (avoid division by zero)
    final safeMaxValue = maxValue > 0 ? maxValue : 100.0;
    final interval = safeMaxValue / 4;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval > 0 ? interval : 25.0,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= stats.length) return const SizedBox.shrink();
              final stat = stats[value.toInt()];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('MMM').format(stat.month),
                  style: context.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: interval > 0 ? interval : 25.0,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              return Text(
                _formatCompactCurrency(value),
                style: context.textTheme.bodySmall,
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
          left: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      minX: 0,
      maxX: stats.isEmpty ? 5.0 : (stats.length - 1).toDouble(),
      minY: minNet < 0 ? minNet * 1.1 : 0,
      maxY: safeMaxValue * 1.1,
      lineBarsData: [
        // Income Line
        LineChartBarData(
          spots: incomeSpots,
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.green,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.withOpacity(0.1),
          ),
        ),
        // Expense Line
        LineChartBarData(
          spots: expenseSpots,
          isCurved: true,
          color: Colors.red,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.red,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.red.withOpacity(0.1),
          ),
        ),
        // Net Line
        LineChartBarData(
          spots: netSpots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          isStrokeCapRound: true,
          dashArray: [5, 5],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: Colors.blue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              String label;
              Color color;
              if (spot.barIndex == 0) {
                label = 'Income';
                color = Colors.green;
              } else if (spot.barIndex == 1) {
                label = 'Expense';
                color = Colors.red;
              } else {
                label = 'Net';
                color = Colors.blue;
              }

              return LineTooltipItem(
                '$label\n${CurrencyUtils.format(spot.y)}',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  String _formatCompactCurrency(double value) {
    // Net values can be negative; compact the magnitude and keep the sign.
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    if (abs >= 100000) {
      return '$sign₹${(abs / 100000).toStringAsFixed(1)}L';
    } else if (abs >= 1000) {
      return '$sign₹${(abs / 1000).toStringAsFixed(1)}K';
    }
    return '$sign₹${abs.toStringAsFixed(0)}';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


