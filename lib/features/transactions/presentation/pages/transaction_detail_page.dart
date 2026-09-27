import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/enums/transaction_type.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../providers/transactions_notifier.dart';

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
                itemBuilder: (context) => [
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
                      final success = await ref
                          .read(transactionsNotifierProvider.notifier)
                          .deleteTransaction(transactionId, transaction);

                      if (success && context.mounted) {
                        context.showSuccessSnackBar(
                            'Transaction deleted successfully');
                        context.pop();
                      } else if (context.mounted) {
                        final state = ref.read(transactionsNotifierProvider);
                        state.whenOrNull(
                          error: (failure) =>
                              context.showErrorSnackBar(failure.message),
                        );
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
            return const Center(
              child: Text('Transaction not found'),
            );
          }

          final categoryAsync = ref.watch(categoryProvider(transaction.categoryId));
          final accountAsync = ref.watch(accountProvider(transaction.accountId));

          return ListView(
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
                          color: transaction.type == TransactionType.income
                              ? Colors.green.withOpacity(0.1)
                              : context.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          transaction.type.displayName,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: transaction.type == TransactionType.income
                                ? Colors.green
                                : context.colorScheme.error,
                          ),
                        ),
                      ),
                      AppSpacing.gapMD,
                      Text(
                        transaction.amount.toCurrency(),
                        style: context.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: transaction.type == TransactionType.income
                              ? Colors.green
                              : context.colorScheme.error,
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
                        'Date',
                        transaction.date.toFormattedDate(),
                      ),
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
                        _buildInfoRow(
                          context,
                          'Attachment',
                          transaction.attachments!.first,
                        ),
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
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              AppSpacing.gapMD,
              Text(
                'Failed to load transaction',
                style: context.textTheme.titleMedium,
              ),
              AppSpacing.gapSM,
              Text(
                error.toString(),
                style: context.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
