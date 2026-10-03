import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../providers/recurring_transactions_notifier.dart';
import 'add_edit_recurring_modal.dart';
import 'recurring_transaction_card.dart';

class RecurringTransactionsModal extends ConsumerWidget {
  const RecurringTransactionsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('Recurring Transactions')),
          body: _buildBody(context, ref),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddRule(context),
            tooltip: 'Add Recurring Transaction',
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
            'Recurring Transactions',
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
          onPressed: () => _showAddRule(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Recurring Transaction'),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final rulesState = ref.watch(recurringTransactionsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);

    final categoriesById = categoriesState.maybeWhen<Map<String, CategoryModel>>(
      loaded: (categories) => {for (final category in categories) category.id: category},
      orElse: () => const {},
    );

    return rulesState.when(
      initial: () => const LoadingIndicator(),
      loading: () => const LoadingIndicator(),
      error: (failure) => ErrorView(
        message: failure.message,
        onRetry: () => ref.read(recurringTransactionsNotifierProvider.notifier).refresh(),
      ),
      loaded: (rules) {
        if (rules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.repeat,
                  size: 64,
                  color: context.colorScheme.outline,
                ),
                AppSpacing.gapMD,
                Text(
                  'No Recurring Transactions',
                  style: context.textTheme.titleMedium,
                ),
                AppSpacing.gapSM,
                Text(
                  'Set up rent, subscriptions or salary to auto-fill each time they\'re due',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXL,
                FilledButton.icon(
                  onPressed: () => _showAddRule(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Recurring Transaction'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: AppSpacing.paddingMD,
          itemCount: rules.length,
          itemBuilder: (context, index) {
            final rule = rules[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index < rules.length - 1 ? 12 : 0),
              child: RecurringTransactionCard(
                rule: rule,
                category: categoriesById[rule.categoryId],
                onTap: () => _showAddRule(context, rule: rule),
                onToggleActive: (isActive) =>
                    ref.read(recurringTransactionsNotifierProvider.notifier).setActive(rule, isActive),
                onDelete: () => _deleteRule(context, ref, rule),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddRule(BuildContext context, {RecurringTransactionModel? rule}) {
    showDialog(
      context: context,
      builder: (context) => AddEditRecurringModal(rule: rule),
    );
  }

  Future<void> _deleteRule(BuildContext context, WidgetRef ref, RecurringTransactionModel rule) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Recurring Transaction',
      message: 'Are you sure you want to delete this recurring transaction? '
          'Transactions already generated from it will not be removed.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final failure =
          await ref.read(recurringTransactionsNotifierProvider.notifier).deleteRule(rule.id);
      if (failure == null && context.mounted) {
        context.showSuccessSnackBar('Recurring transaction deleted successfully');
      } else if (failure != null && context.mounted) {
        context.showErrorSnackBar(failure.message);
      }
    }
  }
}
