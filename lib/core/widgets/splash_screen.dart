import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../constants/app_spacing.dart';
import '../extensions/context_extensions.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.forward();

    // Navigate to appropriate screen after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final authState = ref.read(authStateChangesProvider);
        final isAuthenticated = authState.value != null;
        
        if (isAuthenticated) {
          context.go(RouteConstants.dashboard);
        } else {
          context.go(RouteConstants.login);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset(
                  'eazyvault_logo.png',
                  width: 200,
                  height: 200,
                ),
                AppSpacing.gapXL,
                // App Name
                Text(
                  AppConfig.appName,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.primary,
                  ),
                ),
                AppSpacing.gapSM,
                // App Tagline
                Text(
                  AppConfig.appTagline,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXXL,
                // AVAIL404 Logo
                Image.asset(
                  'avail404.png',
                  width: 200,
                  height: 200,
                ),
                AppSpacing.gapMD,
                // Powered By Text
                Text(
                  'Powered By',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'AVAIL404 Private Limited',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.gapXXL,
                // Loading Indicator
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
