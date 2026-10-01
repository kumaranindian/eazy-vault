import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../data/models/account_financials.dart';

class AccountBreakdownChart extends StatelessWidget {
  const AccountBreakdownChart({
    super.key,
    required this.accounts,
    required this.totalBalance,
    required this.accountFinancials,
  });

  final List<AccountModel> accounts;
  final double totalBalance;
  final Map<String, AccountFinancials> accountFinancials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final chartHeight = context.isCompactHeight
        ? 200.0
        : isMobile
            ? 220.0
            : 320.0;

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter accounts with non-zero balance or any activity (income/expense)
    final activeAccounts = accounts.where((a) {
      final financials = accountFinancials[a.id];
      return a.currentBalance != 0 || 
             (financials != null && (financials.income != 0 || financials.expense != 0));
    }).toList();

    if (activeAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResponsiveLayout(
          theme,
          activeAccounts,
          isMobile: isMobile,
          height: chartHeight,
        ),
      ],
    );
  }

  // Professional color palette
  static const Color openingColor = Color(0xFF6366F1); // Indigo
  static const Color incomeColor = Color(0xFF10B981); // Emerald
  static const Color expenseColor = Color(0xFFEF4444); // Red
  static const Color balanceColor = Color(0xFF3B82F6); // Blue

  /// Fills the available width; only scrolls horizontally (inside the chart
  /// area) when there are more accounts than fit.
  Widget _buildResponsiveLayout(
    ThemeData theme,
    List<AccountModel> activeAccounts, {
    required bool isMobile,
    required double height,
  }) {
    final minWidthPerAccount = isMobile ? 80.0 : 120.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = math.max(
                constraints.maxWidth,
                activeAccounts.length * minWidthPerAccount + 50,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: _buildChart(activeAccounts, isMobile: isMobile),
                ),
              );
            },
          ),
        ),
        AppSpacing.gapMD,
        _buildLegend(theme),
      ],
    );
  }

  Widget _buildChart(List<AccountModel> activeAccounts, {required bool isMobile}) {
    // Calculate max and min values for Y-axis
    double maxValue = 0;
    double minValue = 0;
    for (final account in activeAccounts) {
      final financials = accountFinancials[account.id];
      if (financials != null) {
        final openingAbs = financials.openingBalance.abs();
        final incomeAbs = financials.income.abs();
        final expenseAbs = financials.expense.abs();
        final balanceAbs = financials.balance.abs();
        
        if (!openingAbs.isNaN && openingAbs.isFinite) {
          maxValue = maxValue > openingAbs ? maxValue : openingAbs;
        }
        if (!incomeAbs.isNaN && incomeAbs.isFinite) {
          maxValue = maxValue > incomeAbs ? maxValue : incomeAbs;
        }
        if (!expenseAbs.isNaN && expenseAbs.isFinite) {
          maxValue = maxValue > expenseAbs ? maxValue : expenseAbs;
        }
        if (!balanceAbs.isNaN && balanceAbs.isFinite) {
          maxValue = maxValue > balanceAbs ? maxValue : balanceAbs;
        }
        
        // Check for negative balance
        if (financials.balance < minValue) {
          minValue = financials.balance;
        }
      }
    }
    maxValue = maxValue * 1.1; // Add 10% padding
    minValue = minValue * 1.1; // Add 10% padding for negative values

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue > 0 ? maxValue : 1000,
        minY: minValue < 0 ? minValue : 0,
        groupsSpace: isMobile ? 20 : 30,
        barTouchData: BarTouchData(
          enabled: true,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= activeAccounts.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Text(
                      activeAccounts[index].name,
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ),
                );
              },
              reservedSize: isMobile ? 50 : 60,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isMobile ? 45 : 55,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return Text('0', style: TextStyle(fontSize: isMobile ? 9 : 10));
                }
                return Text(
                  value >= 1000 
                      ? '${(value / 1000).toStringAsFixed(0)}k'
                      : value.toStringAsFixed(0),
                  style: TextStyle(fontSize: isMobile ? 9 : 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxValue > 0 ? maxValue / 5 : 200,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.05),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barGroups: _buildBarGroups(activeAccounts, isMobile: isMobile),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<AccountModel> activeAccounts, {required bool isMobile}) {
    final groups = <BarChartGroupData>[];
    final barWidth = isMobile ? 6.0 : 10.0;
    
    for (int i = 0; i < activeAccounts.length; i++) {
      final account = activeAccounts[i];
      final financials = accountFinancials[account.id];
      
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          // Opening Balance
          BarChartRodData(
            toY: financials?.openingBalance.abs() ?? 0,
            color: openingColor,
            width: barWidth,
            borderRadius: BorderRadius.circular(isMobile ? 2 : 3),
          ),
          // Income
          BarChartRodData(
            toY: financials?.income.abs() ?? 0,
            color: incomeColor,
            width: barWidth,
            borderRadius: BorderRadius.circular(isMobile ? 2 : 3),
          ),
          // Expense
          BarChartRodData(
            toY: financials?.expense.abs() ?? 0,
            color: expenseColor,
            width: barWidth,
            borderRadius: BorderRadius.circular(isMobile ? 2 : 3),
          ),
          // Current Balance (can be negative)
          BarChartRodData(
            toY: financials?.balance ?? 0,
            color: balanceColor,
            width: barWidth,
            borderRadius: BorderRadius.circular(isMobile ? 2 : 3),
          ),
        ],
      ));
    }
    
    return groups;
  }

  Widget _buildLegend(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(theme, 'Opening', openingColor),
        _buildLegendItem(theme, 'Income', incomeColor),
        _buildLegendItem(theme, 'Expense', expenseColor),
        _buildLegendItem(theme, 'Balance', balanceColor),
      ],
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
