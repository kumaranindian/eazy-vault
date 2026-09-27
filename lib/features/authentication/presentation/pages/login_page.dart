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

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final rememberMe = await ref.read(rememberMeProvider.future);
    if (rememberMe) {
      final email = await ref.read(lastEmailProvider.future);
      if (email != null && mounted) {
        setState(() {
          _emailController.text = email;
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authNotifierProvider.notifier).signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );

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
      title: 'Welcome Back',
      subtitle: 'Sign in to continue to EazyVault',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) => Validators.required(value, fieldName: 'Password'),
              onFieldSubmitted: (_) => _handleEmailSignIn(),
              enabled: !_isLoading,
            ),
            AppSpacing.gapSM,
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _rememberMe = value ?? false),
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.push(RouteConstants.forgotPassword),
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            AppSpacing.gapLG,
            ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailSignIn,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign In'),
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
            ),
            AppSpacing.gapXL,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: context.textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.go(RouteConstants.register),
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
