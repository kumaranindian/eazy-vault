import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../extensions/context_extensions.dart';
import 'confirmation_dialog.dart';

/// The single sign-out entry point (app bar action or nav rail item):
/// confirms, calls [AuthNotifier.signOut], then reports success.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key, this.asListTile = false});

  /// Renders as a `ListTile` (for the extended nav rail) instead of an
  /// icon-only `IconButton` (for app bars and the collapsed rail).
  final bool asListTile;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final failure = await ref.read(authNotifierProvider.notifier).signOut();
    if (failure == null && context.mounted) {
      context.showSuccessSnackBar('Logged out successfully');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (asListTile) {
      return ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Sign Out'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: () => _signOut(context, ref),
      );
    }

    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Sign Out',
      onPressed: () => _signOut(context, ref),
    );
  }
}
