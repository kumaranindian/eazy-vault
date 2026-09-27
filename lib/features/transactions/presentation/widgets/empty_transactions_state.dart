import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

class EmptyTransactionsState extends StatelessWidget {
  const EmptyTransactionsState({
    super.key,
    this.onAddTransaction,
  });

  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.paddingXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            AppSpacing.gapLG,
            Text(
              'No Transactions Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.gapSM,
            Text(
              'Start tracking your finances by adding your first transaction',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddTransaction != null) ...[
              AppSpacing.gapXL,
              FilledButton.icon(
                onPressed: onAddTransaction,
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
