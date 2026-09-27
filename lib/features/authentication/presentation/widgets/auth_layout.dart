import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'eazyvault_logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  AppSpacing.gapLG,
                  Text(
                    AppConfig.appName,
                    style: context.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapSM,
                  Text(
                    AppConfig.appTagline,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXXL,
                  Text(
                    title,
                    style: context.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapSM,
                  Text(
                    subtitle,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXL,
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
