import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../constants/app_spacing.dart';
import '../extensions/context_extensions.dart';

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

    // Navigation away from the splash screen is done by the router's
    // redirect as soon as the Firebase auth state is known.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      // Logo sizes follow the current viewport so the splash fits in
      // landscape phones; scrolling is the fallback for very short screens.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final logoSize =
              (constraints.biggest.shortestSide * 0.3).clamp(64.0, 200.0);
          final compact = constraints.maxHeight < 600;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo
                        Image.asset(
                          'eazyvault_logo.png',
                          width: logoSize,
                          height: logoSize,
                        ),
                        compact ? AppSpacing.gapMD : AppSpacing.gapXL,
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
                            color:
                                context.colorScheme.onSurface.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        compact ? AppSpacing.gapLG : AppSpacing.gapXXL,
                        // AVAIL404 Logo
                        Image.asset(
                          'avail404.png',
                          width: logoSize,
                          height: logoSize,
                        ),
                        AppSpacing.gapMD,
                        // Powered By Text
                        Text(
                          'Powered By',
                          style: context.textTheme.bodySmall?.copyWith(
                            color:
                                context.colorScheme.onSurface.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'AVAIL404 Private Limited',
                          style: context.textTheme.bodySmall?.copyWith(
                            color:
                                context.colorScheme.onSurface.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        compact ? AppSpacing.gapLG : AppSpacing.gapXXL,
                        // Loading Indicator
                        const CircularProgressIndicator(
                          semanticsLabel: 'Loading',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
