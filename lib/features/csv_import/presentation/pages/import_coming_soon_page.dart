import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';

/// Placeholder shown at the Import entry point while the real CSV import
/// flow (`CsvImportPage`) is temporarily pulled back. Swap the route in
/// `app_router.dart` back to `CsvImportPage` to restore it; that page and
/// its feature code are untouched.
class ImportComingSoonPage extends StatelessWidget {
  const ImportComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLG,
            child: ResponsiveContent(
              maxWidth: Breakpoints.formMaxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.file_upload_outlined,
                      size: 56,
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  AppSpacing.gapLG,
                  Text(
                    'Import',
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapSM,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: AppSpacing.borderRadiusSM,
                    ),
                    child: const Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  AppSpacing.gapLG,
                  Text(
                    'Bring your financial data into EazyVault with ease.',
                    style: context.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapSM,
                  Text(
                    'Import functionality is currently under development '
                    'and will be available in a future update.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
