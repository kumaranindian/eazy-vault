import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../providers/budget_progress_provider.dart';

/// A single budget's progress: category, spent vs. limit, and a color-coded
/// meter (green under 80%, amber 80-100%, red over). The percentage is
/// always shown as text alongside the color, never color alone.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.progress,
    this.onTap,
    this.onDelete,
  });

  final BudgetProgress progress;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  Color _meterColor(BuildContext context) {
    if (progress.isOverBudget) return context.colorScheme.error;
    if (progress.percentage >= 0.8) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final category = progress.category;
    final meterColor = _meterColor(context);
    final percentLabel = '${(progress.percentage * 100).toStringAsFixed(0)}%';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(category?.icon ?? '📦', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category?.name ?? 'Deleted category',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (progress.isOverBudget)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'OVER',
                        style: TextStyle(
                          color: context.colorScheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                      tooltip: 'Delete budget',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.percentage.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: meterColor.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(meterColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${CurrencyUtils.format(progress.spent)} of ${CurrencyUtils.format(progress.budget.amount)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    percentLabel,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: meterColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
