import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.iconData,
    this.action,
    this.actionLabel,
  });

  final String title;
  final String? message;
  final Widget? icon;
  final IconData? iconData;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.paddingXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              icon!
            else if (iconData != null)
              Icon(
                iconData,
                size: 120,
                color: theme.colorScheme.outline.withOpacity(0.3),
              )
            else
              Icon(
                Icons.inbox_outlined,
                size: 120,
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            AppSpacing.gapLG,
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              AppSpacing.gapSM,
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null && actionLabel != null) ...[
              AppSpacing.gapXL,
              ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
