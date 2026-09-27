import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/double_extensions.dart';

class TransactionListHeader extends StatelessWidget {
  const TransactionListHeader({
    super.key,
    required this.date,
    required this.total,
    required this.isIncome,
  });

  final String date;
  final double total;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.paddingMD,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          if (total != 0)
            Text(
              total.toCurrency(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isIncome ? Colors.green : theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
