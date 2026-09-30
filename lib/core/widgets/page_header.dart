import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/breakpoints.dart';
import '../extensions/context_extensions.dart';
import 'responsive_layout.dart';

/// A page's title/description/actions row, used under a page's `AppBar`.
/// Title+description sit beside the actions when there's room; otherwise
/// they stack so action buttons never overflow. Uses the available layout
/// width (not the screen width), so it adapts correctly inside the
/// navigation rail/sidebar shell too.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (description != null) ...[
          AppSpacing.gapXS,
          Text(
            description!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
    final actionsRow = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            actions.isNotEmpty && constraints.maxWidth < Breakpoints.mobile;

        return ResponsiveContent(
          padding: EdgeInsets.fromLTRB(
            stacked ? AppSpacing.md : AppSpacing.lg,
            AppSpacing.md,
            stacked ? AppSpacing.md : AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleColumn,
                    AppSpacing.gapSM,
                    actionsRow,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: titleColumn),
                    if (actions.isNotEmpty) ...[
                      AppSpacing.gapMD,
                      actionsRow,
                    ],
                  ],
                ),
        );
      },
    );
  }
}
