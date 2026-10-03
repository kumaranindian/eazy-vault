import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/attachment_utils.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/extensions/transaction_extensions.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../providers/transactions_notifier.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/services/account_balance_service.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          transactionAsync.when(
            data: (transaction) {
              if (transaction == null) return const SizedBox.shrink();
              return PopupMenuButton(
                tooltip: 'Transaction actions',
                itemBuilder: (context) => [
                  // Transfers and loans can't be edited, only deleted.
                  if (AccountBalanceService.isEditableType(transaction.type))
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    context.push(
                      RouteConstants.editTransaction
                          .replaceAll(':id', transactionId),
                    );
                  } else if (value == 'delete') {
                    final confirmed = await ConfirmationDialog.show(
                      context,
                      title: 'Delete Transaction',
                      message:
                          'Are you sure you want to delete this transaction? This action cannot be undone.',
                      confirmText: 'Delete',
                      isDestructive: true,
                    );

                    if (confirmed && context.mounted) {
                      final failure = await ref
                          .read(transactionsNotifierProvider.notifier)
                          .deleteTransaction(transactionId, transaction);

                      if (failure == null && context.mounted) {
                        context.showSuccessSnackBar(
                            'Transaction deleted successfully');
                        context.pop();
                      } else if (context.mounted) {
                        context.showErrorSnackBar(failure?.message);
                      }
                    }
                  }
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: transactionAsync.when(
        data: (transaction) {
          if (transaction == null) {
            return const EmptyState(
              title: 'Transaction not found',
              message: 'It may have been deleted.',
              iconData: Icons.receipt_long_outlined,
            );
          }

          final categoryAsync = ref.watch(categoryProvider(transaction.categoryId));
          final accountAsync = ref.watch(accountProvider(transaction.accountId));

          return ResponsiveContent(
            maxWidth: 800,
            child: ListView(
            padding: AppSpacing.paddingMD,
            children: [
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    children: [
                      categoryAsync.when(
                        data: (category) {
                          if (category == null) {
                            return const Icon(
                              Icons.category_outlined,
                              size: 64,
                            );
                          }
                          return Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Color(category.color).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    category.icon,
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                ),
                              ),
                              AppSpacing.gapMD,
                              Text(
                                category.name,
                                style: context.textTheme.titleMedium,
                              ),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Icon(Icons.error_outline),
                      ),
                      AppSpacing.gapMD,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _flowColor(transaction, context).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          transaction.type.displayName,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: _flowColor(transaction, context),
                          ),
                        ),
                      ),
                      AppSpacing.gapMD,
                      Text(
                        transaction.amount.toCurrency(),
                        style: context.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _flowColor(transaction, context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapMD,
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.gapMD,
                      accountAsync.when(
                        data: (account) => _buildInfoRow(
                          context,
                          'Account',
                          account?.name ?? 'Unknown',
                        ),
                        loading: () => _buildInfoRow(
                          context,
                          'Account',
                          'Loading...',
                        ),
                        error: (_, __) => _buildInfoRow(
                          context,
                          'Account',
                          'Error',
                        ),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        transaction.type == TransactionType.income ? 'Credited Date' : 'Date',
                        transaction.date.toFormattedDate(),
                      ),
                      if (transaction.type == TransactionType.income) ...[
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          'Income For',
                          DateTimeUtils.formatMonthYear(transaction.incomeReportingMonth),
                        ),
                      ],
                      if (transaction.description != null) ...[
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          'Description',
                          transaction.description!,
                        ),
                      ],
                      if (transaction.vendor != null) ...[
                        const Divider(height: 24),
                        _buildInfoRow(
                          context,
                          'Vendor',
                          transaction.vendor!,
                        ),
                      ],
                      if (transaction.attachments != null &&
                          transaction.attachments!.isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildAttachmentRow(context, transaction.attachments!.first),
                      ],
                    ],
                  ),
                ),
              ),
              AppSpacing.gapMD,
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metadata',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.gapMD,
                      _buildInfoRow(
                        context,
                        'Created',
                        transaction.createdAt.toFormattedDate(),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        'Last Updated',
                        transaction.updatedAt.toFormattedDate(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorView(
          title: 'Failed to load transaction',
          message: ErrorMessages.from(error, action: 'load this transaction'),
          onRetry: () => ref.invalidate(transactionProvider(transactionId)),
        ),
      ),
    );
  }

  Widget _buildAttachmentRow(BuildContext context, String url) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'Attachment',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => AttachmentUtils.openAttachment(context, url),
            child: Text(
              'View Attachment',
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// Money in is green, money out is red, moves between own accounts and
/// repayments are neutral (see `TransactionModelExtensions.cashFlow`).
Color _flowColor(TransactionModel transaction, BuildContext context) {
  if (transaction.cashFlow > 0) return Colors.green;
  if (transaction.cashFlow < 0) return context.colorScheme.error;
  return context.colorScheme.onSurface;
}
