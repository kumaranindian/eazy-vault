import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../providers/transactions_notifier.dart';
import 'edit_transaction_modal.dart';

class TransactionDetailModal extends ConsumerStatefulWidget {
  const TransactionDetailModal({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<TransactionDetailModal> createState() => _TransactionDetailModalState();
}

class _TransactionDetailModalState extends ConsumerState<TransactionDetailModal> {
  @override
  Widget build(BuildContext context) {
    final transactionAsync = ref.watch(transactionProvider(widget.transactionId));
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: transactionAsync.when(
          data: (transaction) {
            if (transaction == null) {
              return const Padding(
                padding: AppSpacing.paddingXL,
                child: Center(child: Text('Transaction not found')),
              );
            }

            final categoryAsync = ref.watch(categoryProvider(transaction.categoryId));
            final accountAsync = ref.watch(accountProvider(transaction.accountId));

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: AppSpacing.paddingMD,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
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
                      Text(
                        'Transaction Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                SingleChildScrollView(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Center(
                        child: Text(
                          transaction.amount.toCurrency(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: transaction.isIncome
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                        ),
                      ),
                      AppSpacing.gapMD,

                      // Type Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: transaction.isIncome
                                ? Colors.green.withOpacity(0.1)
                                : theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                transaction.isIncome
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                                color: transaction.isIncome
                                    ? Colors.green
                                    : theme.colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                transaction.type.displayName,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: transaction.isIncome
                                      ? Colors.green
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.gapXL,

                      // Details
                      _buildDetailRow(
                        context,
                        'Description',
                        transaction.description ?? 'No description',
                        Icons.description_outlined,
                      ),
                      AppSpacing.gapMD,
                      _buildDetailRow(
                        context,
                        'Category',
                        categoryAsync.whenOrNull(
                          data: (category) => category?.name ?? 'Unknown',
                        ) ?? 'Loading...',
                        Icons.category_outlined,
                      ),
                      AppSpacing.gapMD,
                      _buildDetailRow(
                        context,
                        'Account',
                        accountAsync.whenOrNull(
                          data: (account) => account?.name ?? 'Unknown',
                        ) ?? 'Loading...',
                        Icons.account_balance_wallet_outlined,
                      ),
                      AppSpacing.gapMD,
                      _buildDetailRow(
                        context,
                        'Date',
                        transaction.date.toFormattedDate(),
                        Icons.calendar_today_outlined,
                      ),
                      if (transaction.vendor != null) ...[
                        AppSpacing.gapMD,
                        _buildDetailRow(
                          context,
                          'Vendor',
                          transaction.vendor!,
                          Icons.store_outlined,
                        ),
                      ],
                      if (transaction.attachments != null && transaction.attachments!.isNotEmpty) ...[
                        AppSpacing.gapMD,
                        _buildDetailRow(
                          context,
                          'Attachment',
                          'View Attachment',
                          Icons.attach_file_outlined,
                          isLink: true,
                          url: transaction.attachments!.first,
                        ),
                      ],
                      AppSpacing.gapXL,

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => EditTransactionModal(transactionId: transaction.id),
                                );
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                          ),
                          AppSpacing.gapMD,
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _deleteTransaction(context, ref, transaction),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: AppSpacing.paddingXL,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Padding(
            padding: AppSpacing.paddingXL,
            child: Center(child: Text('Error loading transaction')),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isLink = false,
    String? url,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        AppSpacing.gapSM,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              if (isLink && url != null)
                InkWell(
                  onTap: () {
                    // Open URL
                  },
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
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
      final success = await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transaction.id, transaction);
      if (success && context.mounted) {
        ref.invalidate(currentMonthStatsProvider);
        ref.invalidate(totalBalanceProvider);
        ref.invalidate(recentTransactionsProvider);
        context.showSuccessSnackBar('Transaction deleted successfully');
        Navigator.of(context).pop();
      }
    }
  }
}
