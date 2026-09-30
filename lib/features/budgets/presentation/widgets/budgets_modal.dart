import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/budget_model.dart';
import '../providers/budget_progress_provider.dart';
import '../providers/budgets_notifier.dart';
import 'add_edit_budget_modal.dart';
import 'budget_card.dart';

class BudgetsModal extends ConsumerWidget {
  const BudgetsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('Budgets')),
          body: _buildBody(context, ref),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddBudget(context),
            tooltip: 'Add Budget',
            child: const Icon(Icons.add),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final dialogWidth = isTablet ? screenWidth * 0.85 : screenWidth * 0.7;
    final dialogHeight = isTablet ? screenHeight * 0.85 : screenHeight * 0.8;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppConfig.appName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppConfig.appTagline,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'All Budgets',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _buildBody(context, ref),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => _showAddBudget(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Budget'),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final budgetsState = ref.watch(budgetsNotifierProvider);

    return budgetsState.when(
      initial: () => const LoadingIndicator(),
      loading: () => const LoadingIndicator(),
      error: (failure) => ErrorView(
        message: failure.message,
        onRetry: () => ref.read(budgetsNotifierProvider.notifier).refresh(),
      ),
      loaded: (budgets) {
        if (budgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: 64,
                  color: context.colorScheme.outline,
                ),
                AppSpacing.gapMD,
                Text(
                  'No Budgets Yet',
                  style: context.textTheme.titleMedium,
                ),
                AppSpacing.gapSM,
                Text(
                  'Set a monthly limit for a category to start tracking it',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXL,
                FilledButton.icon(
                  onPressed: () => _showAddBudget(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Budget'),
                ),
              ],
            ),
          );
        }

        return Consumer(
          builder: (context, ref, child) {
            final progressAsync = ref.watch(budgetProgressProvider);
            return progressAsync.when(
              data: (progressList) => ListView.builder(
                padding: AppSpacing.paddingMD,
                itemCount: progressList.length,
                itemBuilder: (context, index) {
                  final progress = progressList[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < progressList.length - 1 ? 12 : 0,
                    ),
                    child: BudgetCard(
                      progress: progress,
                      onTap: () => _showAddBudget(context, budget: progress.budget),
                      onDelete: () => _deleteBudget(context, ref, progress.budget),
                    ),
                  );
                },
              ),
              loading: () => const LoadingIndicator(),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load budget progress',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddBudget(BuildContext context, {BudgetModel? budget}) {
    showDialog(
      context: context,
      builder: (context) => AddEditBudgetModal(budget: budget),
    );
  }

  Future<void> _deleteBudget(BuildContext context, WidgetRef ref, BudgetModel budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
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
      final failure = await ref.read(budgetsNotifierProvider.notifier).deleteBudget(budget.id);
      if (failure == null && context.mounted) {
        context.showSuccessSnackBar('Budget deleted successfully');
      } else if (failure != null && context.mounted) {
        context.showErrorSnackBar(failure.message);
      }
    }
  }
}
