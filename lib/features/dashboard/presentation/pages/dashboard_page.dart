import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../accounts/presentation/widgets/accounts_modal.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/presentation/widgets/categories_modal.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/providers/financial_refresh.dart';
import '../../../transactions/presentation/providers/transactions_notifier.dart';
import '../../../transactions/presentation/widgets/transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_detail_modal.dart';
import '../../../transactions/presentation/widgets/transactions_modal.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/summary_card.dart';
import '../widgets/account_breakdown_chart.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/add_transaction_tabbed_modal.dart';
import '../widgets/account_balances_card.dart';
import '../widgets/loans_summary_card.dart';
import '../widgets/upcoming_bills_widget.dart';
import '../widgets/spending_trends_chart.dart';
import '../../data/models/account_financials.dart';
import '../../../transactions/presentation/widgets/transfer_transaction_form.dart';
import '../../../transactions/presentation/widgets/loan_transaction_form.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(currentMonthStatsProvider);
    final accountsState = ref.watch(accountsNotifierProvider);
    final currentUser = ref.watch(currentUserProvider);
    final accountFinancialsAsync = ref.watch(accountFinancialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppConfig.appName,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              AppConfig.appTagline,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: context.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    currentUser.email?.split('@')[0] ?? 'User',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                final failure = await ref.read(authNotifierProvider.notifier).signOut();
                if (failure == null && context.mounted) {
                  context.showSuccessSnackBar('Logged out successfully');
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Reloads account balances too (totalBalance and the account
                // chart are derived from the accounts list).
                refreshFinancialData(ref.invalidate);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppSpacing.paddingMD,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DashboardHeader(
                            totalBalance: totalBalance,
                            accounts: accountsState.maybeWhen(
                              loaded: (accounts) => accounts,
                              orElse: () => [],
                            ),
                            totalIncome: monthlyStats.maybeWhen(
                              data: (stats) => stats.income,
                              orElse: () => 0.0,
                            ),
                            totalExpense: monthlyStats.maybeWhen(
                              data: (stats) => stats.expense,
                              orElse: () => 0.0,
                            ),
                            accountFinancials: accountFinancialsAsync.maybeWhen(
                              data: (financials) => financials,
                              orElse: () => {},
                            ),
                          ),
                          AppSpacing.gapXL,
                          Text(
                            'This Month',
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.gapMD,
                          monthlyStats.when(
                            data: (stats) => Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SummaryCard(
                                        title: 'Income',
                                        amount: stats.income,
                                        icon: Icons.arrow_upward,
                                        color: Colors.green,
                                      ),
                                    ),
                                    AppSpacing.gapMD,
                                    Expanded(
                                      child: SummaryCard(
                                        title: 'Expense',
                                        amount: stats.expense,
                                        icon: Icons.arrow_downward,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                AppSpacing.gapMD,
                                SummaryCard(
                                  title: 'Net Savings',
                                  amount: stats.income - stats.expense,
                                  icon: Icons.savings_outlined,
                                  color: stats.income - stats.expense >= 0
                                      ? Colors.blue
                                      : Colors.orange,
                                  isFullWidth: true,
                                ),
                              ],
                            ),
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (error, stack) => Center(
                              child: Padding(
                                padding: AppSpacing.paddingMD,
                                child: Text(
                                  'Failed to load statistics',
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: context.colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          AppSpacing.gapXL,
                          Text(
                            'Quick Actions',
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.gapMD,
                          Row(
                            children: [
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Add Income',
                                  icon: Icons.add_circle_outline,
                                  color: Colors.green,
                                  onTap: () => _showAddTransactionDialog(context, TransactionType.income),
                                ),
                              ),
                              AppSpacing.gapMD,
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Add Expense',
                                  icon: Icons.remove_circle_outline,
                                  color: Colors.red,
                                  onTap: () => _showAddTransactionDialog(context, TransactionType.expense),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapMD,
                          Row(
                            children: [
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Transfer',
                                  icon: Icons.swap_horiz,
                                  color: Colors.orange,
                                  onTap: () => _showTransferDialog(context),
                                ),
                              ),
                              AppSpacing.gapMD,
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Lend',
                                  icon: Icons.arrow_upward,
                                  color: Colors.teal,
                                  onTap: () => _showLoanDialog(context, TransactionType.loanGiven),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapMD,
                          Row(
                            children: [
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Borrow',
                                  icon: Icons.arrow_downward,
                                  color: Colors.deepOrange,
                                  onTap: () => _showLoanDialog(context, TransactionType.loanTaken),
                                ),
                              ),
                              AppSpacing.gapMD,
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Accounts',
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: Colors.blue,
                                  onTap: () => _showAccountsModal(context),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapMD,
                          Row(
                            children: [
                              Expanded(
                                child: QuickActionButton(
                                  label: 'Categories',
                                  icon: Icons.category_outlined,
                                  color: Colors.purple,
                                  onTap: () => _showCategoriesModal(context),
                                ),
                              ),
                              AppSpacing.gapMD,
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                          AppSpacing.gapXL,
                          // Loans Summary Card
                          const LoansSummaryCard(),
                          AppSpacing.gapXL,
                          // Upcoming Bills Widget
                          const UpcomingBillsWidget(),
                          AppSpacing.gapXL,
                          // Spending Trends Chart
                          const SpendingTrendsChart(),
                          AppSpacing.gapXL,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Transactions',
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const TransactionsModal(),
                                  );
                                },
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final recentTransactionsStream = ref.watch(
                        recentTransactionsProvider(limit: 5),
                      );

                      return recentTransactionsStream.when(
                        data: (transactions) {
                          if (transactions.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding: AppSpacing.paddingMD,
                                child: Card(
                                  child: Padding(
                                    padding: AppSpacing.paddingLG,
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 48,
                                          color: context.colorScheme.primary.withOpacity(0.5),
                                        ),
                                        AppSpacing.gapMD,
                                        Text(
                                          'No Recent Transactions',
                                          style: context.textTheme.titleMedium,
                                        ),
                                        AppSpacing.gapSM,
                                        Text(
                                          'Start tracking your finances by adding your first transaction',
                                          style: context.textTheme.bodySmall?.copyWith(
                                            color: context.colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        AppSpacing.gapMD,
                                        FilledButton.tonal(
                                          onPressed: () => _showAddTransactionDialog(context, TransactionType.expense),
                                          child: const Text('Add Transaction'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: AppSpacing.paddingMD,
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final transaction = transactions[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index < transactions.length - 1 ? 8 : 0,
                                    ),
                                    child: TransactionCard(
                                      transaction: transaction,
                                      onTap: () => _showTransactionDetailModal(context, transaction.id),
                                      onDelete: () => _deleteTransaction(context, ref, transaction),
                                      onEdit: () => _editTransaction(context, transaction),
                                    ),
                                  );
                                },
                                childCount: transactions.length,
                              ),
                            ),
                          );
                        },
                        loading: () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (error, stack) => const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ),
          // Footer - Always visible
          Container(
            padding: AppSpacing.paddingMD,
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Powered By',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    'AVAIL404 Private Limited',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddTransactionTabbedModal(),
          );
        },
        tooltip: 'new transactions',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, TransactionType type) {
    showDialog(
      context: context,
      builder: (context) => AddTransactionDialog(type: type),
    );
  }

  void _showAccountsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AccountsModal(),
    );
  }

  void _showCategoriesModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CategoriesModal(),
    );
  }

  void _showTransactionDetailModal(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (context) => TransactionDetailModal(transactionId: transactionId),
    );
  }

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref, TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final failure = await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transaction.id, transaction);
      if (failure == null && context.mounted) {
        context.showSuccessSnackBar('Transaction deleted successfully');
      } else if (failure != null && context.mounted) {
        context.showErrorSnackBar(failure.message);
      }
    }
  }

  void _editTransaction(BuildContext context, TransactionModel transaction) {
    context.push(
      RouteConstants.editTransaction.replaceAll(':id', transaction.id),
    );
  }

  void _showTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TransferTransactionForm(
              onSuccess: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showLoanDialog(BuildContext context, TransactionType loanType) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LoanTransactionForm(
              loanType: loanType,
              onSuccess: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }
}
