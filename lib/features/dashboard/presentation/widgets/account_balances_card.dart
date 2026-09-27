import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../accounts/data/models/account_model.dart';

class AccountBalancesCard extends StatelessWidget {
  const AccountBalancesCard({
    super.key,
    required this.accounts,
    required this.totalBalance,
  });

  final List<AccountModel> accounts;
  final double totalBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Balances',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Individual account balances
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: isMobile ? 200 : 250,
                    child: _buildAccountBalancesList(theme, isMobile),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 20),
                // Right side: Total balance
                Expanded(
                  flex: 1,
                  child: _buildTotalBalanceSection(theme, isMobile),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            // Bar chart representation
            SizedBox(
              height: isMobile ? 150 : 200,
              child: _buildBarChart(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountBalancesList(ThemeData theme, bool isMobile) {
    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return Padding(
          padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          child: Row(
            children: [
              Container(
                width: isMobile ? 32 : 40,
                height: isMobile ? 32 : 40,
                decoration: BoxDecoration(
                  color: Color(account.color),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: isMobile ? 16 : 20,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      account.type.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                account.currentBalance.toCurrency(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: account.currentBalance >= 0 
                      ? Colors.green 
                      : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalBalanceSection(ThemeData theme, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            totalBalance.toCurrency(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: totalBalance >= 0 
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  totalBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: isMobile ? 14 : 16,
                  color: totalBalance >= 0 ? Colors.green : Colors.red,
                ),
                SizedBox(width: isMobile ? 4 : 6),
                Text(
                  totalBalance >= 0 ? 'Positive' : 'Negative',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: totalBalance >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            '${accounts.length} ${accounts.length == 1 ? 'Account' : 'Accounts'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(bool isMobile) {
    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = accounts
        .map((a) => a.currentBalance.abs())
        .reduce((a, b) => a > b ? a : b) * 1.1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue > 0 ? maxValue : 1000,
        minY: 0,
        groupsSpace: isMobile ? 8 : 12,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= accounts.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    accounts[index].name.length > (isMobile ? 4 : 6)
                        ? '${accounts[index].name.substring(0, isMobile ? 4 : 6)}...'
                        : accounts[index].name,
                    style: TextStyle(
                      fontSize: isMobile ? 8 : 9,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
              reservedSize: isMobile ? 30 : 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isMobile ? 40 : 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return Text('0', style: TextStyle(fontSize: isMobile ? 8 : 9));
                }
                return Text(
                  value >= 1000 
                      ? '${(value / 1000).toStringAsFixed(0)}k'
                      : value.toStringAsFixed(0),
                  style: TextStyle(fontSize: isMobile ? 8 : 9),
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
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? maxValue / 5 : 200,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: accounts.asMap().entries.map((entry) {
          final index = entry.key;
          final account = entry.value;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: account.currentBalance.abs(),
                color: Color(account.color),
                width: isMobile ? 8.0 : 12.0,
                borderRadius: BorderRadius.circular(isMobile ? 2 : 3),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
