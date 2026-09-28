import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../constants/breakpoints.dart';
import '../extensions/context_extensions.dart';

/// A form-style modal that renders as a centered [AlertDialog] on tablet/
/// desktop and as a full-screen page (app bar + scrollable body + a sticky
/// action footer) on mobile, so forms push in like a native app screen
/// instead of popping up as a small dialog.
class AdaptiveFormDialog extends StatelessWidget {
  const AdaptiveFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.isLoading = false,
  });

  final String title;
  final Widget content;

  /// Same buttons used for the desktop [AlertDialog.actions] row and,
  /// stacked, as the mobile footer.
  final List<Widget> actions;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed:
                  isLoading ? null : () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(top: false, child: content),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions,
            ),
          ),
        ),
      );
    }

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
                onPressed:
                    isLoading ? null : () => Navigator.of(context).pop(),
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
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(width: 500, child: content),
      actions: actions,
    );
  }
}
