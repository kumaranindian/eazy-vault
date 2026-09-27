import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_notifier.dart';
import '../widgets/auth_layout.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authNotifierProvider.notifier).sendPasswordResetEmail(
          _emailController.text.trim(),
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      setState(() => _emailSent = true);
      context.showSuccessSnackBar('Password reset email sent! Please check your inbox.');
    } else {
      final authState = ref.read(authNotifierProvider);
      authState.whenOrNull(
        error: (failure) => context.showErrorSnackBar(failure.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Forgot Password',
      subtitle: _emailSent
          ? 'Check your email for password reset instructions'
          : 'Enter your email to receive password reset instructions',
      child: _emailSent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: context.colorScheme.primary,
                ),
                AppSpacing.gapLG,
                Text(
                  'Email Sent!',
                  style: context.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapMD,
                Text(
                  'We have sent password reset instructions to ${_emailController.text.trim()}',
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXL,
                ElevatedButton(
                  onPressed: () => context.go(RouteConstants.login),
                  child: const Text('Back to Sign In'),
                ),
                AppSpacing.gapMD,
                TextButton(
                  onPressed: () => setState(() => _emailSent = false),
                  child: const Text('Resend Email'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: Validators.email,
                    onFieldSubmitted: (_) => _handlePasswordReset(),
                    enabled: !_isLoading,
                  ),
                  AppSpacing.gapLG,
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handlePasswordReset,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Reset Link'),
                  ),
                  AppSpacing.gapXL,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remember your password? ',
                        style: context.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => context.go(RouteConstants.login),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
