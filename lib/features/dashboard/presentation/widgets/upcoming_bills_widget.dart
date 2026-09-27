import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/extensions/transaction_extensions.dart';
import '../../../transactions/domain/models/loan_metadata.dart';
import '../../../transactions/presentation/providers/loan_providers.dart';

class UpcomingBillsWidget extends ConsumerWidget {
  const UpcomingBillsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLoansAsync = ref.watch(activeLoansProvider);

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
                  Icons.notifications_active,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Bills',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bills List
            activeLoansAsync.when(
              data: (loans) {
                final allLoans = [...loans.loansGiven, ...loans.loansTaken];
                final upcomingBills = _getUpcomingBills(allLoans);

                if (upcomingBills.isEmpty) {
                  return _EmptyState();
                }

                return Column(
                  children: upcomingBills.map((bill) {
                    return _BillItem(
                      transaction: bill.transaction,
                      daysUntilDue: bill.daysUntilDue,
                      isOverdue: bill.isOverdue,
                    );
                  }).toList(),
                );
              },
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => const _LoadingBillItem(),
                ),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load bills',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_UpcomingBill> _getUpcomingBills(List<TransactionModel> loans) {
    final now = DateTime.now();
    final bills = <_UpcomingBill>[];

    for (final loan in loans) {
      final loanMetadata = loan.loanMetadata;
      if (loanMetadata == null || loanMetadata.dueDate == null) continue;

      // Skip completed loans
      if (loanMetadata.status == LoanStatus.completed) continue;

      final dueDate = loanMetadata.dueDate!;
      final daysUntilDue = dueDate.difference(now).inDays;

      // Show bills due in next 30 days or overdue
      if (daysUntilDue <= 30) {
        bills.add(_UpcomingBill(
          transaction: loan,
          daysUntilDue: daysUntilDue,
          isOverdue: daysUntilDue < 0,
        ));
      }
    }

    // Sort by due date (overdue first, then by days)
    bills.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      return a.daysUntilDue.compareTo(b.daysUntilDue);
    });

    return bills.take(5).toList(); // Show max 5 bills
  }
}

class _BillItem extends StatelessWidget {
  const _BillItem({
    required this.transaction,
    required this.daysUntilDue,
    required this.isOverdue,
  });

  final TransactionModel transaction;
  final int daysUntilDue;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final loanMetadata = transaction.loanMetadata!;
    final isLoanGiven = transaction.type == TransactionType.loanGiven;
    final remainingAmount = loanMetadata.remainingAmount ?? transaction.amount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.05)
            : daysUntilDue <= 7
                ? Colors.orange.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : daysUntilDue <= 7
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isLoanGiven
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLoanGiven ? Icons.arrow_upward : Icons.arrow_downward,
              color: isLoanGiven ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loanMetadata.partyName ?? 'Unknown',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getDueDateText(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? Colors.red
                            : daysUntilDue <= 7
                                ? Colors.orange
                                : context.colorScheme.onSurfaceVariant,
                        fontWeight: isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.format(remainingAmount),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLoanGiven ? Colors.green : Colors.red,
                ),
              ),
              if (isOverdue)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OVERDUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDueDateText() {
    if (isOverdue) {
      final daysOverdue = daysUntilDue.abs();
      if (daysOverdue == 0) return 'Due today';
      if (daysOverdue == 1) return 'Overdue by 1 day';
      return 'Overdue by $daysOverdue days';
    }

    if (daysUntilDue == 0) return 'Due today';
    if (daysUntilDue == 1) return 'Due tomorrow';
    if (daysUntilDue <= 7) return 'Due in $daysUntilDue days';
    if (daysUntilDue <= 14) return 'Due in ${(daysUntilDue / 7).ceil()} week${(daysUntilDue / 7).ceil() > 1 ? 's' : ''}';
    return 'Due in ${(daysUntilDue / 7).ceil()} weeks';
  }
}

class _LoadingBillItem extends StatelessWidget {
  const _LoadingBillItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No upcoming bills',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'re all caught up!',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBill {
  final TransactionModel transaction;
  final int daysUntilDue;
  final bool isOverdue;

  _UpcomingBill({
    required this.transaction,
    required this.daysUntilDue,
    required this.isOverdue,
  });
}
