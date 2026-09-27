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
import '../widgets/google_sign_in_button.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authNotifierProvider.notifier).signUpWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.showSuccessSnackBar('Account created successfully! Please verify your email.');
      context.go(RouteConstants.dashboard);
    } else {
      final authState = ref.read(authNotifierProvider);
      authState.whenOrNull(
        error: (failure) => context.showErrorSnackBar(failure.message),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final success = await ref.read(authNotifierProvider.notifier).signInWithGoogle();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.go(RouteConstants.dashboard);
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
      title: 'Create Account',
      subtitle: 'Sign up to get started with EazyVault',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              prefixIcon: const Icon(Icons.person_outlined),
              validator: (value) => Validators.name(value, fieldName: 'Name'),
              enabled: !_isLoading,
            ),
            AppSpacing.gapMD,
            AppTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: Validators.email,
              enabled: !_isLoading,
            ),
            AppSpacing.gapMD,
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: Validators.password,
              enabled: !_isLoading,
            ),
            AppSpacing.gapMD,
            AppTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (value) => Validators.confirmPassword(value, _passwordController.text),
              onFieldSubmitted: (_) => _handleEmailSignUp(),
              enabled: !_isLoading,
            ),
            AppSpacing.gapLG,
            ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailSignUp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Up'),
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: AppSpacing.horizontalMD,
                  child: Text(
                    'OR',
                    style: context.textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            AppSpacing.gapMD,
            GoogleSignInButton(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              label: 'Sign up with Google',
            ),
            AppSpacing.gapXL,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
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
