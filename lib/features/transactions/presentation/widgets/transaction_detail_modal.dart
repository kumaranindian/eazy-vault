import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/breakpoints.dart';
import '../../../../core/widgets/branded_dialog_title.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/extensions/transaction_extensions.dart';
import '../../domain/models/loan_metadata.dart';
import '../../domain/services/account_balance_service.dart';
import '../providers/transactions_notifier.dart';
import 'attachments_section.dart';
import 'edit_transaction_modal.dart';
import 'loan_repayment_form.dart';
import '../../../../core/widgets/form_dialog.dart';

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
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('Transaction Details')),
          body: SafeArea(top: false, child: _buildBody(context, isMobile: true)),
        ),
      );
    }

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: _buildBody(context, isMobile: false),
      ),
    );
  }

  Widget _buildBody(BuildContext context, {required bool isMobile}) {
    final transactionAsync = ref.watch(transactionProvider(widget.transactionId));
    final theme = Theme.of(context);

    return transactionAsync.when(
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
                // Header (the mobile Scaffold's AppBar covers this instead)
                if (!isMobile)
                Container(
                  padding: AppSpacing.paddingMD,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusXL),
                    ),
                  ),
                  child: BrandedDialogTitle(
                    title: const Text('Transaction Details'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content: Flexible so it scrolls when the dialog is limited
                // by a short viewport (landscape, keyboard).
                Flexible(
                  child: SingleChildScrollView(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                          transaction.amount.toCurrency(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _flowColor(transaction, theme),
                          ),
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
                            color: _flowColor(transaction, theme).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _flowIcon(transaction),
                                size: 16,
                                color: _flowColor(transaction, theme),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                transaction.type.displayName,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _flowColor(transaction, theme),
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
                          data: (category) =>
                              category?.name ??
                              (transaction.isTransfer || transaction.isLoan
                                  ? transaction.type.displayName
                                  : 'Unknown'),
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
                        transaction.type == TransactionType.income ? 'Credited Date' : 'Date',
                        transaction.date.toFormattedDate(),
                        Icons.calendar_today_outlined,
                      ),
                      if (transaction.type == TransactionType.income) ...[
                        AppSpacing.gapMD,
                        _buildDetailRow(
                          context,
                          'Income For',
                          DateTimeUtils.formatMonthYear(transaction.incomeReportingMonth),
                          Icons.event_note_outlined,
                        ),
                      ],
                      if (transaction.vendor != null) ...[
                        AppSpacing.gapMD,
                        _buildDetailRow(
                          context,
                          'Vendor',
                          transaction.vendor!,
                          Icons.store_outlined,
                        ),
                      ],
                      AppSpacing.gapMD,
                      AttachmentsSection(transaction: transaction),
                      AppSpacing.gapXL,

                      // Actions: side by side when there's room, stacked
                      // full-width buttons on narrow phones.
                      _ActionButtons(
                        children: [
                          // Transfers and loans can't be edited (only deleted
                          // and re-created); see AccountBalanceService.
                          if (AccountBalanceService.isEditableType(transaction.type))
                            OutlinedButton.icon(
                              onPressed: _isDeleting
                                  ? null
                                  : () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (context) => EditTransactionModal(transactionId: transaction.id),
                                      );
                                    },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                          if ((transaction.type == TransactionType.loanGiven ||
                                  transaction.type == TransactionType.loanTaken) &&
                              transaction.loanMetadata?.status != LoanStatus.completed)
                            OutlinedButton.icon(
                              onPressed: _isDeleting
                                  ? null
                                  : () => _showRepaymentDialog(context, transaction),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Repayment'),
                            ),
                          FilledButton.icon(
                            onPressed: _isDeleting
                                ? null
                                : () => _deleteTransaction(context, ref, transaction),
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_outline),
                            label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: AppSpacing.paddingXL,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => ErrorView(
            title: 'Could not load transaction',
            message: 'Please check your connection and try again.',
            onRetry: () => ref.invalidate(transactionProvider(widget.transactionId)),
          ),
        );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
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

  /// Money in is green, money out is red, moves between own accounts and
  /// repayments are neutral (see `TransactionModelExtensions.cashFlow`).
  static Color _flowColor(TransactionModel transaction, ThemeData theme) {
    if (transaction.cashFlow > 0) return Colors.green;
    if (transaction.cashFlow < 0) return theme.colorScheme.error;
    return theme.colorScheme.onSurface;
  }

  static IconData _flowIcon(TransactionModel transaction) {
    if (transaction.cashFlow > 0) return Icons.arrow_upward;
    if (transaction.cashFlow < 0) return Icons.arrow_downward;
    return Icons.swap_horiz;
  }

  void _showRepaymentDialog(BuildContext context, TransactionModel loan) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    void onSuccess(BuildContext dialogContext) {
      Navigator.of(dialogContext).pop();
      // Close the detail modal too; the loan's data has changed.
      Navigator.of(context).pop();
    }

    if (isMobile) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: const Text('Record Repayment')),
            body: SafeArea(
              top: false,
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: LoanRepaymentForm(
                  loanTransaction: loan,
                  onSuccess: () => onSuccess(dialogContext),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => FormDialog(
        child: LoanRepaymentForm(
              loanTransaction: loan,
              onSuccess: () => onSuccess(dialogContext),
        ),
      ),
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
      setState(() => _isDeleting = true);
      final failure = await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transaction.id, transaction);
      if (mounted) setState(() => _isDeleting = false);
      if (failure == null && context.mounted) {
        context.showSuccessSnackBar('Transaction deleted successfully');
        Navigator.of(context).pop();
      } else if (failure != null && context.mounted) {
        context.showErrorSnackBar(failure.message);
      }
    }
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 120.0 * children.length + AppSpacing.md) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) AppSpacing.gapSM,
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) AppSpacing.gapMD,
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}
