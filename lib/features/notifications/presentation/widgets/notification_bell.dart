import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/models/app_alert.dart';
import '../providers/active_alerts_provider.dart';

/// Always-available in-app alert list — works even when browser
/// notifications are disabled/denied/unsupported.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(activeAlertsProvider);
    final alerts = alertsAsync.valueOrNull ?? const <AppAlert>[];

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => _showAlerts(context, alerts),
      icon: Badge(
        label: Text('${alerts.length}'),
        isLabelVisible: alerts.isNotEmpty,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  void _showAlerts(BuildContext context, List<AppAlert> alerts) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: AppSpacing.paddingMD,
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: alerts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: AppSpacing.paddingLG,
                          child: Text("You're all caught up!"),
                        ),
                      )
                    : ListView.separated(
                        padding: AppSpacing.paddingMD,
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => AppSpacing.gapSM,
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return ListTile(
                            leading: Icon(
                              alert.severity == AlertSeverity.critical
                                  ? Icons.error_outline
                                  : alert.severity == AlertSeverity.warning
                                      ? Icons.warning_amber_outlined
                                      : Icons.info_outline,
                              color: alert.severity == AlertSeverity.critical
                                  ? Colors.red
                                  : alert.severity == AlertSeverity.warning
                                      ? Colors.orange
                                      : null,
                            ),
                            title: Text(alert.title),
                            subtitle: Text(alert.body),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
