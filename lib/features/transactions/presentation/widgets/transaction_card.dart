import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/services/account_balance_service.dart';
import '../../domain/extensions/transaction_extensions.dart';
import '../../domain/models/loan_metadata.dart';

class TransactionCard extends ConsumerWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.onEdit,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Transfers and loans use placeholder category ids ('transfer'/'loan')
    // that have no category document, so don't look them up.
    final categoryAsync = transaction.isTransfer || transaction.isLoan
        ? const AsyncValue<CategoryModel?>.data(null)
        : ref.watch(categoryProvider(transaction.categoryId));
    final accountAsync = ref.watch(accountProvider(transaction.accountId));

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
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
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onError,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusLG,
          child: Padding(
            padding: AppSpacing.paddingMD,
            child: Row(
              children: [
                _buildTransactionIcon(theme, categoryAsync),
                AppSpacing.gapMD,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.displayTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (transaction.isLoan) ...[
                            AppSpacing.gapXS,
                            _buildLoanStatusBadge(theme),
                          ] else if (transaction.vendor != null) ...[
                            AppSpacing.gapXS,
                            Icon(
                              Icons.store_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ],
                        ],
                      ),
                      AppSpacing.gapXS,
                      Row(
                        children: [
                          Flexible(
                            child: categoryAsync.whenOrNull(
                              data: (category) => category != null
                                  ? Text(
                                      category.name,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : const SizedBox.shrink(),
                            ) ?? const SizedBox.shrink(),
                          ),
                          if (categoryAsync.value != null) ...[
                            Text(
                              ' • ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                          Flexible(
                            child: accountAsync.whenOrNull(
                              data: (account) => account != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        account.name,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color:
                                              theme.colorScheme.onPrimaryContainer,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ) ?? const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      if (transaction.vendor != null) ...[
                        AppSpacing.gapXS,
                        Text(
                          transaction.vendor!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                AppSpacing.gapMD,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          transaction.amount.toCurrency(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _amountColor(theme),
                          ),
                        ),
                        if (onEdit != null || onDelete != null) ...[
                          AppSpacing.gapSM,
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit?.call();
                              } else if (value == 'delete') {
                                onDelete?.call();
                              }
                            },
                            itemBuilder: (context) => [
                              // Transfers and loans can't be edited.
                              if (onEdit != null &&
                                  AccountBalanceService.isEditableType(transaction.type))
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                              if (onDelete != null)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    AppSpacing.gapXS,
                    Text(
                      transaction.date.toFormattedDate(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Money in is green, money out is red, transfers (net zero) are neutral.
  Color _amountColor(ThemeData theme) {
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.loanTaken:
        return Colors.green;
      case TransactionType.transfer:
      case TransactionType.loanRepayment:
        return theme.colorScheme.onSurface;
      case TransactionType.expense:
      case TransactionType.loanGiven:
        return theme.colorScheme.error;
    }
  }

  Widget _buildTransactionIcon(
    ThemeData theme,
    AsyncValue<CategoryModel?> categoryAsync,
  ) {
    // Special handling for transfer and loan transactions
    if (transaction.isTransfer) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: AppSpacing.borderRadiusLG,
        ),
        child: const Center(
          child: Icon(Icons.swap_horiz, color: Colors.orange, size: 24),
        ),
      );
    }

    if (transaction.isLoan) {
      final color = transaction.type == TransactionType.loanGiven
          ? Colors.green
          : transaction.type == TransactionType.loanTaken
              ? Colors.red
              : Colors.blue;
      final icon = transaction.type == TransactionType.loanGiven
          ? Icons.arrow_upward
          : transaction.type == TransactionType.loanTaken
              ? Icons.arrow_downward
              : Icons.payment;

      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: AppSpacing.borderRadiusLG,
        ),
        child: Center(
          child: Icon(icon, color: color, size: 24),
        ),
      );
    }

    // Default category icon
    return categoryAsync.when(
      data: (category) {
        if (category == null) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppSpacing.borderRadiusLG,
            ),
            child: const Icon(Icons.category_outlined),
          );
        }
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(category.color).withOpacity(0.2),
            borderRadius: AppSpacing.borderRadiusLG,
          ),
          child: Center(
            child: Text(
              category.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
      loading: () => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppSpacing.borderRadiusLG,
        ),
      ),
      error: (_, __) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppSpacing.borderRadiusLG,
        ),
        child: const Icon(Icons.error_outline),
      ),
    );
  }

  Widget _buildLoanStatusBadge(ThemeData theme) {
    final loanMetadata = transaction.loanMetadata;
    if (loanMetadata == null) return const SizedBox.shrink();

    Color badgeColor;
    switch (loanMetadata.status) {
      case LoanStatus.pending:
        badgeColor = Colors.orange;
        break;
      case LoanStatus.partial:
        badgeColor = Colors.blue;
        break;
      case LoanStatus.completed:
        badgeColor = Colors.green;
        break;
      case LoanStatus.overdue:
        badgeColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        loanMetadata.status.displayName.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}
