import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../constants/app_spacing.dart';
import '../constants/breakpoints.dart';

/// The EazyVault name/tagline header used on dialogs, followed by the
/// dialog's own [title] and optional [actions] (e.g. a close button).
///
/// On short viewports (landscape phones) the brand block is dropped so the
/// dialog's content keeps its room.
class BrandedDialogTitle extends StatelessWidget {
  const BrandedDialogTitle({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact =
        Breakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              AppSpacing.gapSM,
              Flexible(
                child: Text(
                  AppConfig.appName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppConfig.appTagline,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          AppSpacing.gapSM,
        ],
        Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                child: title,
              ),
            ),
            ...actions,
          ],
        ),
      ],
    );
  }
}
