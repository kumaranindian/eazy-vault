import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/breakpoints.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Oops! Something went wrong',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Smaller illustration on short viewports (landscape phones) and narrow
    // hosts such as dialogs, so the message and button stay visible.
    final compact =
        Breakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);
    final iconSize = compact ? 64.0 : 120.0;

    return Center(
      child: Padding(
        padding: compact ? AppSpacing.paddingMD : AppSpacing.paddingXL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: iconSize,
              color: theme.colorScheme.error.withOpacity(0.5),
            ),
            AppSpacing.gapLG,
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapSM,
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              compact ? AppSpacing.gapMD : AppSpacing.gapXL,
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
