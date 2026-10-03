import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/branded_dialog_title.dart';

/// Shown once, after a user's first successful login (see
/// `HasSeenGettingStartedNotifier`). Returns `true` if the user chose
/// "Show Me How" (caller should open the Getting Started walkthrough),
/// `false` for "Skip for Now" or dismissal.
class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      scrollable: true,
      title: const BrandedDialogTitle(title: Text('Welcome to EazyVault')),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your money, organized in one place.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapSM,
          const Text(
            'Track your accounts, expenses, budgets, bills, loans and '
            'financial progress — all from one place.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip for Now'),
        ),
        AppSpacing.gapSM,
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Show Me How'),
        ),
      ],
    );
  }

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const WelcomeDialog(),
    );
    return result ?? false;
  }
}
