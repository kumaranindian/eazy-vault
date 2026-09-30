import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../domain/extensions/recurring_transaction_extensions.dart';

class RecurringTransactionCard extends StatelessWidget {
  const RecurringTransactionCard({
    super.key,
    required this.rule,
    required this.category,
    this.onTap,
    this.onToggleActive,
    this.onDelete,
  });

  final RecurringTransactionModel rule;
  final CategoryModel? category;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = rule.type == TransactionType.income;
    final flowColor = isIncome ? Colors.green : context.colorScheme.error;
    final subtitle = rule.isFinished
        ? 'Finished'
        : 'Next: ${rule.nextDueDate.toFormattedDate()}';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: flowColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: flowColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.description?.isNotEmpty == true
                          ? rule.description!
                          : (category?.name ?? 'Unknown category'),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rule.frequency.displayName} · $subtitle',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: rule.isFinished
                            ? context.colorScheme.error
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.format(rule.amount),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: flowColor,
                    ),
                  ),
                  if (onToggleActive != null)
                    Switch(
                      value: rule.isActive,
                      onChanged: onToggleActive,
                    ),
                ],
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
