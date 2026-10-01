import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/widgets/recalculate_balances_action.dart';
import '../../data/models/account_financials.dart';
import 'account_breakdown_chart.dart';

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({
    super.key,
    required this.totalBalance,
    required this.accounts,
    required this.totalIncome,
    required this.totalExpense,
    required this.accountFinancials,
  });

  final double totalBalance;
  final List<AccountModel> accounts;
  final double totalIncome;
  final double totalExpense;
  final Map<String, AccountFinancials> accountFinancials;

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  bool _isBalanceVisible = false;
  bool _isAccountBalanceVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;

    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Total Balance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _HeaderIconButton(
                            icon: Icons.info_outline,
                            tooltip: 'Financial summary',
                            onPressed: () => _showFinancialSummary(context),
                          ),
                          // Rebuilds stored balances from transactions.
                          const SyncBalancesButton(),
                        ],
                      ),
                      SizedBox(height: isMobile ? 8 : 12),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                              _isBalanceVisible 
                                  ? widget.totalBalance.toCurrency()
                                  : 'XXX,XXX.XX',
                              style: (isMobile 
                                  ? theme.textTheme.headlineMedium 
                                  : theme.textTheme.headlineLarge)?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              ),
                            ),
                          ),
                          _HeaderIconButton(
                            icon: _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                            tooltip: _isBalanceVisible ? 'Hide balance' : 'Show balance',
                            size: 20,
                            onPressed: () {
                              setState(() {
                                _isBalanceVisible = !_isBalanceVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.totalBalance >= 0 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.totalBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                                  color: widget.totalBalance >= 0 ? Colors.green : Colors.red,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.totalBalance >= 0 ? 'Positive' : 'Negative',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: widget.totalBalance >= 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${widget.accounts.length} ${widget.accounts.length == 1 ? 'account' : 'accounts'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.accounts.isNotEmpty) ...[
              SizedBox(height: isMobile ? 16 : 20),
              _buildAccountSummary(theme, isMobile),
            ],
            if (widget.accounts.isNotEmpty && widget.totalBalance != 0) ...[
              SizedBox(height: isMobile ? 16 : 20),
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Breakdown',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    AccountBreakdownChart(
                      accounts: widget.accounts,
                      totalBalance: widget.totalBalance,
                      accountFinancials: widget.accountFinancials,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSummary(ThemeData theme, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Account Summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              _HeaderIconButton(
                icon: _isAccountBalanceVisible ? Icons.visibility : Icons.visibility_off,
                tooltip: _isAccountBalanceVisible
                    ? 'Hide account balances'
                    : 'Show account balances',
                onPressed: () {
                  setState(() {
                    _isAccountBalanceVisible = !_isAccountBalanceVisible;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          ResponsiveGrid(
            minItemWidth: 140,
            maxColumns: 6,
            spacing: isMobile ? 8 : 12,
            runSpacing: isMobile ? 8 : 12,
            children: widget.accounts.map((account) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: Color(account.color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Color(account.color).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _HeaderIconButton(
                          icon: Icons.info_outline,
                          tooltip: '${account.name} summary',
                          size: isMobile ? 14 : 16,
                          onPressed: () => _showAccountFinancialSummary(context, account),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      _isAccountBalanceVisible 
                          ? account.currentBalance.toCurrency()
                          : 'XXX,XXX.XX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: account.currentBalance >= 0 
                            ? Colors.green 
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showFinancialSummary(BuildContext context) {
    final theme = Theme.of(context);
    final openingBalance = widget.accounts.fold<double>(
      0,
      (sum, account) => sum + account.openingBalance,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppConfig.appName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppConfig.appTagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Financial Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryItem(
              context,
              'Opening Balance',
              openingBalance.toCurrency(),
              Icons.account_balance,
              theme.colorScheme.tertiary,
            ),
            const Divider(),
            _buildSummaryItem(
              context,
              'Total Income',
              widget.totalIncome.toCurrency(),
              Icons.arrow_upward,
              Colors.green,
            ),
            const Divider(),
            _buildSummaryItem(
              context,
              'Total Expense',
              widget.totalExpense.toCurrency(),
              Icons.arrow_downward,
              Colors.red,
            ),
            const Divider(),
            _buildSummaryItem(
              context,
              'Current Balance',
              widget.totalBalance.toCurrency(),
              Icons.account_balance_wallet,
              widget.totalBalance >= 0 ? theme.colorScheme.primary : Colors.red,
              isHighlighted: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAccountFinancialSummary(BuildContext context, AccountModel account) {
    final theme = Theme.of(context);
    final financials = widget.accountFinancials[account.id];
    
    if (financials == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppConfig.appName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppConfig.appTagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(account.color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        account.type.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryItem(
              context,
              'Opening Balance',
              financials.openingBalance.toCurrency(),
              Icons.account_balance,
              theme.colorScheme.tertiary,
            ),
            const Divider(),
            _buildSummaryItem(
              context,
              'Income',
              financials.income.toCurrency(),
              Icons.arrow_upward,
              Colors.green,
            ),
            const Divider(),
            _buildSummaryItem(
              context,
              'Expense',
              financials.expense.toCurrency(),
              Icons.arrow_downward,
              Colors.red,
            ),
            const Divider(),
            _buildSummaryItem(
              context,
              'Current Balance',
              financials.balance.toCurrency(),
              Icons.account_balance_wallet,
              financials.balance >= 0 ? theme.colorScheme.primary : Colors.red,
              isHighlighted: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          // Label and value share the row so narrow dialogs wrap instead of
          // overflowing.
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: isHighlighted ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon action with a tooltip (screen readers announce it) and a
/// compact but still tappable hit area.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 18,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: size,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
    );
  }
}
