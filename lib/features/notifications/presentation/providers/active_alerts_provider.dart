import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../budgets/presentation/providers/budget_progress_provider.dart';
import '../../../transactions/presentation/providers/loan_providers.dart';
import '../../domain/models/app_alert.dart';
import '../../domain/services/alert_evaluator.dart';
import 'notification_settings_provider.dart';
import 'notifications_providers.dart';

part 'active_alerts_provider.g.dart';

/// Every budget/bill alert current data produces — always current, shown by
/// the in-app notification bell regardless of browser-notification state.
@riverpod
Future<List<AppAlert>> activeAlerts(ActiveAlertsRef ref) async {
  final budgets = await ref.watch(budgetProgressProvider.future);
  final loans = await ref.watch(activeLoansProvider.future);
  final allLoans = [...loans.loansGiven, ...loans.loansTaken];

  return [
    ...AlertEvaluator.evaluateBudgetAlerts(budgets),
    ...AlertEvaluator.evaluateBillAlerts(allLoans),
  ];
}

/// Fires a browser notification for any newly-crossed alert. Watched once
/// from the dashboard (same one-shot-per-session shape as
/// `recurringTransactionsCatchUpProvider`); re-runs whenever the underlying
/// budget/loan data changes.
@Riverpod(keepAlive: true)
Future<int> notificationDispatch(NotificationDispatchRef ref) async {
  final alerts = await ref.watch(activeAlertsProvider.future);
  final enabled = await ref.watch(notificationSettingsNotifierProvider.future);
  final dispatchService = await ref.watch(notificationDispatchServiceProvider.future);
  return dispatchService.dispatchNew(alerts, enabled: enabled);
}
