import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../extensions/context_extensions.dart';
import 'confirmation_dialog.dart';

/// The single sign-out entry point (app bar action or nav rail item):
/// confirms, calls [AuthNotifier.signOut], then reports success.
class SignOutButton extends ConsumerStatefulWidget {
  const SignOutButton({super.key, this.asListTile = false});

  /// Renders as a `ListTile` (for the extended nav rail) instead of an
  /// icon-only `IconButton` (for app bars and the collapsed rail).
  final bool asListTile;

  @override
  ConsumerState<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<SignOutButton> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSigningOut = true);
    final success = await ref.read(authNotifierProvider.notifier).signOut();
    if (!mounted) return;
    setState(() => _isSigningOut = false);

    if (success) {
      context.showSuccessSnackBar('Logged out successfully');
    } else {
      final state = ref.read(authNotifierProvider);
      state.whenOrNull(error: (failure) => context.showErrorSnackBar(failure.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asListTile) {
      return ListTile(
        leading: _isSigningOut
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout),
        title: Text(_isSigningOut ? 'Signing out...' : 'Sign Out'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: _isSigningOut ? null : _signOut,
      );
    }

    return IconButton(
      icon: _isSigningOut
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
      tooltip: 'Sign Out',
      onPressed: _isSigningOut ? null : _signOut,
    );
  }
}
