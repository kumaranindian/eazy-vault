import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../budgets/presentation/providers/budget_progress_provider.dart';
import '../../../budgets/presentation/widgets/add_edit_budget_modal.dart';
import '../../../budgets/presentation/widgets/budget_card.dart';
import '../../../budgets/presentation/widgets/budgets_modal.dart';

/// A compact, at-a-glance view of active budgets on the dashboard: the
/// worst-off (highest % spent) ones, up to a small cap, with a link to the
/// full list.
class BudgetsSummaryCard extends ConsumerWidget {
  const BudgetsSummaryCard({super.key});

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, color: context.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Budgets',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => const BudgetsModal(),
                  ),
                  tooltip: 'View all budgets',
                ),
              ],
            ),
            const SizedBox(height: 12),
            progressAsync.when(
              data: (progressList) {
                if (progressList.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set a monthly limit for a category to start tracking it here.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => const AddEditBudgetModal(),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Set Up Budget'),
                      ),
                    ],
                  );
                }

                final preview = progressList.take(_previewCount).toList();

                return Column(
                  children: [
                    for (int i = 0; i < preview.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i < preview.length - 1 ? 10 : 0),
                        child: BudgetCard(
                          progress: preview[i],
                          onTap: () => showDialog(
                            context: context,
                            builder: (context) => const BudgetsModal(),
                          ),
                        ),
                      ),
                    if (progressList.length > _previewCount) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => const BudgetsModal(),
                        ),
                        child: Text('View all ${progressList.length} budgets'),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Failed to load budgets',
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
