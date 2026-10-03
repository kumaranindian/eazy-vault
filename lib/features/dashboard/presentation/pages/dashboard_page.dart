import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/sign_out_button.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../accounts/presentation/widgets/accounts_modal.dart';
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
import '../widgets/category_breakdown_chart.dart';
import '../widgets/net_worth_chart.dart';
import '../widgets/budgets_summary_card.dart';
import '../../../budgets/presentation/widgets/budgets_modal.dart';
import '../../../recurring_transactions/presentation/providers/recurring_catch_up_provider.dart';
import '../../../recurring_transactions/presentation/widgets/recurring_transactions_modal.dart';
import '../../data/models/account_financials.dart';
import '../../../transactions/presentation/widgets/transfer_transaction_form.dart';
import '../../../transactions/presentation/widgets/loan_transaction_form.dart';
import '../../../../core/widgets/form_dialog.dart';
import '../../../reports/domain/enums/report_type.dart';
import '../../../reports/presentation/widgets/export_config_sheet.dart';
import '../../../notifications/presentation/providers/active_alerts_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(currentMonthStatsProvider);
    final accountsState = ref.watch(accountsNotifierProvider);
    final currentUser = ref.watch(currentUserProvider);
    final accountFinancialsAsync = ref.watch(accountFinancialsProvider);
    final isCompactHeight = context.isCompactHeight;

    // Runs once per session: generates any transactions due recurring rules
    // owe, then tells the user how many were added.
    ref.listen<AsyncValue<int>>(recurringTransactionsCatchUpProvider, (previous, next) {
      next.whenOrNull(
        data: (generatedCount) {
          if (generatedCount > 0) {
            context.showSuccessSnackBar(
              '$generatedCount recurring transaction${generatedCount > 1 ? 's' : ''} added',
            );
          }
        },
      );
    });

    // Fires a browser notification for any newly-crossed budget/bill alert.
    // The in-app bell (below) always reflects current alerts regardless.
    ref.watch(notificationDispatchProvider);

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
                Flexible(
                  child: Text(
                    AppConfig.appName,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              AppConfig.appTagline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          // The user name is hidden on phones so the title keeps its room.
          if (currentUser != null && !context.isMobile)
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
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(RouteConstants.profile),
          ),
          const SignOutButton(),
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
                    child: ResponsiveContent(
                      padding: AppSpacing.paddingMD,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.gapMD,
                          // 2 columns on phones, one row on wide screens.
                          ResponsiveGrid(
                            minItemWidth: 120,
                            maxColumns: 9,
                            children: [
                              QuickActionButton(
                                label: 'Add Income',
                                icon: Icons.add_circle_outline,
                                color: Colors.green,
                                onTap: () => _showAddTransactionDialog(
                                    context, TransactionType.income),
                              ),
                              QuickActionButton(
                                label: 'Add Expense',
                                icon: Icons.remove_circle_outline,
                                color: Colors.red,
                                onTap: () => _showAddTransactionDialog(
                                    context, TransactionType.expense),
                              ),
                              QuickActionButton(
                                label: 'Transfer',
                                icon: Icons.swap_horiz,
                                color: Colors.orange,
                                onTap: () => _showTransferDialog(context),
                              ),
                              QuickActionButton(
                                label: 'Lend',
                                icon: Icons.arrow_upward,
                                color: Colors.teal,
                                onTap: () => _showLoanDialog(
                                    context, TransactionType.loanGiven),
                              ),
                              QuickActionButton(
                                label: 'Borrow',
                                icon: Icons.arrow_downward,
                                color: Colors.deepOrange,
                                onTap: () => _showLoanDialog(
                                    context, TransactionType.loanTaken),
                              ),
                              QuickActionButton(
                                label: 'Accounts',
                                icon: Icons.account_balance_wallet_outlined,
                                color: Colors.blue,
                                onTap: () => _showAccountsModal(context),
                              ),
                              QuickActionButton(
                                label: 'Categories',
                                icon: Icons.category_outlined,
                                color: Colors.purple,
                                onTap: () => _showCategoriesModal(context),
                              ),
                              QuickActionButton(
                                label: 'Budgets',
                                icon: Icons.savings_outlined,
                                color: Colors.teal,
                                onTap: () => _showBudgetsModal(context),
                              ),
                              QuickActionButton(
                                label: 'Recurring',
                                icon: Icons.repeat,
                                color: Colors.indigo,
                                onTap: () => _showRecurringModal(context),
                              ),
                              QuickActionButton(
                                label: 'Reports',
                                icon: Icons.summarize_outlined,
                                color: Colors.brown,
                                onTap: () => context.push(RouteConstants.reports),
                              ),
                              QuickActionButton(
                                label: 'Import',
                                icon: Icons.file_upload_outlined,
                                color: Colors.cyan,
                                onTap: () => context.push(RouteConstants.importTransactions),
                              ),
                            ],
                          ),
                          AppSpacing.gapXL,
                          DashboardHeader(
                            totalBalance: totalBalance,
                            accounts: accountsState.maybeWhen(
                              loaded: (accounts) => accounts,
                              orElse: () => <AccountModel>[],
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
                              orElse: () => <String, AccountFinancials>{},
                            ),
                          ),
                          AppSpacing.gapXL,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'This Month',
                                  style: context.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.file_download_outlined),
                                tooltip: 'Export',
                                onPressed: () => ExportConfigSheet.show(
                                  context,
                                  reportType: ReportType.monthly,
                                  initialMonth: DateTime.now(),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapMD,
                          monthlyStats.when(
                            data: (stats) => _MonthlySummary(
                              income: stats.income,
                              expense: stats.expense,
                            ),
                            loading: () => const Padding(
                              padding: AppSpacing.paddingXL,
                              child: LoadingIndicator(size: 32),
                            ),
                            error: (error, stack) => _InlineError(
                              message: 'Failed to load statistics',
                              onRetry: () =>
                                  ref.invalidate(currentMonthStatsProvider),
                            ),
                          ),
                          AppSpacing.gapXL,
                          // Side by side when there's room, stacked otherwise.
                          const ResponsiveGrid(
                            minItemWidth: 420,
                            maxColumns: 2,
                            spacing: AppSpacing.lg,
                            runSpacing: AppSpacing.xl,
                            children: [
                              LoansSummaryCard(),
                              BudgetsSummaryCard(),
                              UpcomingBillsWidget(),
                            ],
                          ),
                          AppSpacing.gapXL,
                          // Net Worth Chart
                          const NetWorthChart(),
                          AppSpacing.gapXL,
                          // Spending Trends Chart
                          const SpendingTrendsChart(),
                          AppSpacing.gapXL,
                          // Category Breakdown Chart
                          const CategoryBreakdownChart(),
                          AppSpacing.gapXL,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Recent Transactions',
                                  style: context.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) =>
                                        const TransactionsModal(),
                                  );
                                },
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                          AppSpacing.gapMD,
                          _RecentTransactions(
                            onAdd: () => _showAddTransactionDialog(
                                context, TransactionType.expense),
                            onTap: (transaction) => _showTransactionDetailModal(
                                context, transaction.id),
                            onDelete: (transaction) =>
                                _deleteTransaction(context, ref, transaction),
                            onEdit: (transaction) =>
                                _editTransaction(context, transaction),
                          ),
                          // On short viewports (landscape phones) the footer
                          // scrolls with the content instead of taking space.
                          if (isCompactHeight) ...[
                            AppSpacing.gapXL,
                            const _PoweredByFooter(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Keeps the last card clear of the floating action button.
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ),
          if (!isCompactHeight)
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: context.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: const _PoweredByFooter(),
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

  void _showBudgetsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BudgetsModal(),
    );
  }

  void _showRecurringModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RecurringTransactionsModal(),
    );
  }

  void _showTransactionDetailModal(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (context) =>
          TransactionDetailModal(transactionId: transactionId),
    );
  }

  Future<void> _deleteTransaction(
      BuildContext context, WidgetRef ref, TransactionModel transaction) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete this transaction? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final failure = await ref
          .read(transactionsNotifierProvider.notifier)
          .deleteTransaction(transaction.id, transaction);
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
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    if (isMobile) {
      showDialog(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: const Text('Transfer')),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: AppSpacing.paddingMD,
                child: TransferTransactionForm(
                  onSuccess: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => FormDialog(
        child: TransferTransactionForm(
          onSuccess: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showLoanDialog(BuildContext context, TransactionType loanType) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final title = loanType == TransactionType.loanGiven ? 'Lend Money' : 'Borrow Money';

    if (isMobile) {
      showDialog(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              top: false,
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: LoanTransactionForm(
                  loanType: loanType,
                  onSuccess: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => FormDialog(
        child: LoanTransactionForm(
          loanType: loanType,
          onSuccess: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    final incomeCard = SummaryCard(
      title: 'Income',
      amount: income,
      icon: Icons.arrow_upward,
      color: Colors.green,
    );
    final expenseCard = SummaryCard(
      title: 'Expense',
      amount: expense,
      icon: Icons.arrow_downward,
      color: Colors.red,
    );
    final netCard = SummaryCard(
      title: 'Net Savings',
      amount: net,
      icon: Icons.savings_outlined,
      color: net >= 0 ? Colors.blue : Colors.orange,
      isFullWidth: true,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on tablets/desktops; income + expense over net savings
        // on phones.
        if (constraints.maxWidth >= Breakpoints.mobile) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: incomeCard),
                AppSpacing.gapMD,
                Expanded(child: expenseCard),
                AppSpacing.gapMD,
                Expanded(child: netCard),
              ],
            ),
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: incomeCard),
                AppSpacing.gapMD,
                Expanded(child: expenseCard),
              ],
            ),
            AppSpacing.gapMD,
            SizedBox(width: double.infinity, child: netCard),
          ],
        );
      },
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions({
    required this.onAdd,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  final VoidCallback onAdd;
  final void Function(TransactionModel) onTap;
  final void Function(TransactionModel) onDelete;
  final void Function(TransactionModel) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentTransactions = ref.watch(recentTransactionsProvider(limit: 5));

    return recentTransactions.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Card(
            child: Padding(
              padding: AppSpacing.paddingLG,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      textAlign: TextAlign.center,
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
                      onPressed: onAdd,
                      child: const Text('Add Transaction'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < transactions.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i < transactions.length - 1 ? AppSpacing.sm : 0,
                ),
                child: TransactionCard(
                  transaction: transactions[i],
                  onTap: () => onTap(transactions[i]),
                  onDelete: () => onDelete(transactions[i]),
                  onEdit: () => onEdit(transactions[i]),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: AppSpacing.paddingXL,
        child: LoadingIndicator(size: 32),
      ),
      error: (error, stack) => _InlineError(
        message: 'Failed to load recent transactions',
        onRetry: () => ref.invalidate(recentTransactionsProvider(limit: 5)),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingMD,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PoweredByFooter extends StatelessWidget {
  const _PoweredByFooter();

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurface.withOpacity(0.5),
      fontStyle: FontStyle.italic,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Powered By', style: style),
          Text(
            'AVAIL404 Private Limited',
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
