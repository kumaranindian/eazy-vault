import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/presentation/providers/loan_providers.dart';
import '../../../transactions/presentation/widgets/loan_transaction_form.dart';
import '../../../transactions/presentation/widgets/transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_detail_modal.dart';
import '../../../../core/widgets/form_dialog.dart';
import '../../../../core/utils/error_messages.dart';

class LoansSummaryCard extends ConsumerWidget {
  const LoansSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLoansAsync = ref.watch(activeLoansProvider);
    final totalOwedToYouAsync = ref.watch(totalOwedToYouProvider);
    final totalYouOweAsync = ref.watch(totalYouOweProvider);
    final overdueLoansAsync = ref.watch(overdueLoansProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.handshake,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Loans & Debts',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () async {
                    final ({
                      List<TransactionModel> loansGiven,
                      List<TransactionModel> loansTaken
                    }) loans;
                    try {
                      loans = await ref.read(activeLoansProvider.future);
                    } catch (e) {
                      if (context.mounted) {
                        context.showErrorSnackBar(
                          ErrorMessages.from(e, action: 'load your loans'),
                        );
                      }
                      return;
                    }
                    if (!context.mounted) return;
                    _showLoansList(
                      context,
                      'Active loans',
                      [...loans.loansGiven, ...loans.loansTaken],
                    );
                  },
                  tooltip: 'View all loans',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Overdue Alert
            overdueLoansAsync.when(
              data: (overdueLoans) {
                if (overdueLoans.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${overdueLoans.length} overdue loan${overdueLoans.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _showLoansList(context, 'Overdue loans', overdueLoans),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Summary Stats
            activeLoansAsync.when(
              data: (loans) {
                final loansGivenCount = loans.loansGiven.length;
                final loansTakenCount = loans.loansTaken.length;

                return Column(
                  children: [
                    // Money Owed to You
                    totalOwedToYouAsync.when(
                      data: (totalOwed) => _SummaryRow(
                        icon: Icons.arrow_upward,
                        iconColor: Colors.green,
                        label: 'Owed to You',
                        amount: totalOwed,
                        count: loansGivenCount,
                      ),
                      loading: () => const _LoadingSummaryRow(),
                      error: (_, __) => const _SummaryUnavailable(),
                    ),
                    const SizedBox(height: 12),

                    // Money You Owe
                    totalYouOweAsync.when(
                      data: (totalOwe) => _SummaryRow(
                        icon: Icons.arrow_downward,
                        iconColor: Colors.red,
                        label: 'You Owe',
                        amount: totalOwe,
                        count: loansTakenCount,
                      ),
                      loading: () => const _LoadingSummaryRow(),
                      error: (_, __) => const _SummaryUnavailable(),
                    ),
                  ],
                );
              },
              loading: () => Column(
                children: const [
                  _LoadingSummaryRow(),
                  SizedBox(height: 12),
                  _LoadingSummaryRow(),
                ],
              ),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load loans',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showLoanForm(context, TransactionType.loanGiven),
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Lend'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showLoanForm(context, TransactionType.loanTaken),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('Borrow'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLoanForm(BuildContext context, TransactionType loanType) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => FormDialog(
        child: LoanTransactionForm(
              loanType: loanType,
              onSuccess: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  void _showLoansList(
    BuildContext context,
    String title,
    List<TransactionModel> loans,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: loans.isEmpty
              ? const Text('No loans to show.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: loans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => TransactionCard(
                    transaction: loans[index],
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      showDialog<void>(
                        context: context,
                        builder: (_) => TransactionDetailModal(
                          transactionId: loans[index].id,
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
    required this.count,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyUtils.format(amount),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingSummaryRow extends StatelessWidget {
  const _LoadingSummaryRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryUnavailable extends StatelessWidget {
  const _SummaryUnavailable();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Total unavailable. Pull down to refresh.',
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.error,
      ),
    );
  }
}
