import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/responsive_layout.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: CompanyInfo.email);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        context.showErrorSnackBar('Unable to open your email app');
      }
    } catch (_) {
      if (context.mounted) {
        context.showErrorSnackBar('Unable to open your email app');
      }
    }
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: ResponsiveContent(
        maxWidth: Breakpoints.formMaxWidth,
        child: ListView(
          padding: AppSpacing.paddingMD,
          children: [
            Center(
              child: Image.asset(
                AssetConstants.logo,
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
            AppSpacing.gapMD,
            Center(
              child: Text(
                AppConfig.appName,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.gapXS,
            Center(
              child: Text(
                AppConfig.appTagline,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.gapXL,
            const Divider(),
            AppSpacing.gapMD,
            _sectionTitle(context, 'About EazyVault'),
            AppSpacing.gapSM,
            Text(
              '${AppConfig.appName} is a personal finance management '
              'application designed to help users organize and track their '
              'financial activities in one place.',
              style: context.textTheme.bodyMedium,
            ),
            AppSpacing.gapXL,
            const Divider(),
            AppSpacing.gapMD,
            _sectionTitle(context, 'About Avail404'),
            AppSpacing.gapSM,
            Text(
              CompanyInfo.companyName,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              CompanyInfo.tagline,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            AppSpacing.gapSM,
            Text(
              '${CompanyInfo.brandName} develops software products focused '
              'on making everyday processes simpler through practical and '
              'easy-to-use technology.',
              style: context.textTheme.bodyMedium,
            ),
            AppSpacing.gapXL,
            const Divider(),
            AppSpacing.gapMD,
            _sectionTitle(context, 'Contact'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(
                CompanyInfo.email,
                style: TextStyle(
                  color: context.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
              trailing: const Icon(Icons.north_east, size: 16),
              onTap: () => _launchEmail(context),
            ),
            AppSpacing.gapXL,
            const Divider(),
            AppSpacing.gapMD,
            _sectionTitle(context, CompanyInfo.officeAddressLabel),
            AppSpacing.gapSM,
            Text(
              CompanyInfo.officeAddress,
              style: context.textTheme.bodyMedium,
            ),
            AppSpacing.gapXL,
            const Divider(),
            AppSpacing.gapMD,
            Center(
              child: Text(
                '© ${DateTime.now().year} ${CompanyInfo.companyName}.\n'
                'All rights reserved.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.gapMD,
          ],
        ),
      ),
    );
  }
}
