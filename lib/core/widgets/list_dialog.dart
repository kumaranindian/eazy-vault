import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/breakpoints.dart';
import 'branded_dialog_title.dart';

/// Tall dialog for browsing a list (accounts, categories): branded header
/// with a close button, a scrolling [body] and [actions] that wrap onto
/// several lines on narrow screens instead of overflowing.
///
/// The height follows the current viewport, so rotation and browser resizes
/// re-layout it; [Dialog] additionally shrinks it when the keyboard is open.
class ListDialog extends StatelessWidget {
  const ListDialog({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;

  /// Fills the space between header and actions; should scroll itself.
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontal =
        Breakpoints.isMobile(size.width) ? AppSpacing.md : AppSpacing.lg;

    return Dialog(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: Breakpoints.listDialogMaxWidth),
        child: SizedBox(
          height: size.height * 0.9,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  horizontal,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: BrandedDialogTitle(
                  title: Text(title),
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
              if (actions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.sm,
                    horizontal,
                    horizontal,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: AppSpacing.sm,
                      overflowSpacing: AppSpacing.sm,
                      children: actions,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
