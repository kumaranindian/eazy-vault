import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/sign_out_button.dart';
import '../../domain/enums/report_type.dart';
import '../widgets/export_config_sheet.dart';

const _reportIcons = {
  ReportType.monthly: Icons.calendar_view_month_outlined,
  ReportType.transactionStatement: Icons.receipt_long_outlined,
  ReportType.accountStatement: Icons.account_balance_wallet_outlined,
  ReportType.income: Icons.trending_up_outlined,
  ReportType.expense: Icons.trending_down_outlined,
  ReportType.category: Icons.pie_chart_outline,
  ReportType.loansDebts: Icons.handshake_outlined,
  ReportType.annual: Icons.insert_chart_outlined,
};

/// The Reports hub: one tile per report type, each opening the shared
/// `ExportConfigSheet` for that type. Reached from the dashboard's "Reports"
/// quick action — there's no room for a 5th bottom-nav tab (see
/// `AppScaffold`), so this is a routed page instead.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: const [SignOutButton()],
      ),
      body: Column(
        children: [
          const PageHeader(
            title: 'Reports',
            description: 'Export your financial data as PDF or Excel.',
          ),
          Expanded(
            child: ResponsiveContent(
              padding: AppSpacing.paddingMD,
              child: ResponsiveGrid(
                minItemWidth: 260,
                maxColumns: 3,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final type in ReportType.values)
                    _ReportTile(
                      reportType: type,
                      icon: _reportIcons[type]!,
                      onTap: () => ExportConfigSheet.show(context, reportType: type),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.reportType,
    required this.icon,
    required this.onTap,
  });

  final ReportType reportType;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLG,
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: AppSpacing.borderRadiusLG,
                ),
                child: Icon(icon, color: context.colorScheme.onPrimaryContainer),
              ),
              AppSpacing.gapMD,
              Text(
                reportType.displayName,
                style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              AppSpacing.gapXS,
              Text(
                reportType.description,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
