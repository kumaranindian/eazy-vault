import '../../../budgets/presentation/providers/budget_progress_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/extensions/transaction_extensions.dart';
import '../../../transactions/domain/models/loan_metadata.dart';
import '../models/app_alert.dart';

/// Pure threshold/due-date logic for budget and bill alerts — no Firestore,
/// SharedPreferences or browser APIs, so it's trivial to unit test.
class AlertEvaluator {
  const AlertEvaluator._();

  static const List<int> _budgetThresholds = [100, 90, 80];

  /// One alert per budget that's crossed a threshold this period, for the
  /// highest threshold reached (crossing 95% doesn't also alert for 80%).
  /// The key includes the calendar month, so a new month starts fresh.
  static List<AppAlert> evaluateBudgetAlerts(
    List<BudgetProgress> budgets, {
    DateTime? now,
  }) {
    final period = _monthKey(now ?? DateTime.now());
    final alerts = <AppAlert>[];

    for (final progress in budgets) {
      final percent = (progress.percentage * 100).round();
      final threshold = _budgetThresholds.firstWhere(
        (t) => percent >= t,
        orElse: () => 0,
      );
      if (threshold == 0) continue;

      final name = progress.category?.name ?? 'budget';
      alerts.add(AppAlert(
        key: 'budget:${progress.budget.id}:$period:$threshold',
        title: threshold >= 100 ? 'Budget exceeded' : 'Budget alert',
        body: threshold >= 100
            ? "You've used all of your $name budget."
            : "You're at $threshold% of your $name budget.",
        severity: threshold >= 100 ? AlertSeverity.critical : AlertSeverity.warning,
      ));
    }

    return alerts;
  }

  /// One alert per active loan whose due date falls in a bucket worth
  /// reminding about: 3 days out, tomorrow, today, or overdue. The key
  /// includes the calendar day so each bucket fires once, except "overdue"
  /// which re-fires daily until the loan is resolved.
  static List<AppAlert> evaluateBillAlerts(
    List<TransactionModel> loans, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayKey = _dateKey(today);
    final alerts = <AppAlert>[];

    for (final loan in loans) {
      final metadata = loan.loanMetadata;
      final dueDate = metadata?.dueDate;
      if (metadata == null || dueDate == null) continue;
      if (metadata.status == LoanStatus.completed) continue;

      final daysUntilDue = DateTime(dueDate.year, dueDate.month, dueDate.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      final name = metadata.partyName ?? 'Someone';

      String? bucket;
      String body;
      if (daysUntilDue < 0) {
        bucket = 'overdue';
        body = '$name\'s payment is overdue.';
      } else if (daysUntilDue == 0) {
        bucket = 'today';
        body = '$name\'s payment is due today.';
      } else if (daysUntilDue == 1) {
        bucket = 'tomorrow';
        body = '$name\'s payment is due tomorrow.';
      } else if (daysUntilDue == 3) {
        bucket = '3days';
        body = '$name\'s payment is due in 3 days.';
      } else {
        continue;
      }

      alerts.add(AppAlert(
        key: bucket == 'overdue'
            ? 'bill:${loan.id}:overdue:$todayKey'
            : 'bill:${loan.id}:$bucket',
        title: bucket == 'overdue' ? 'Payment overdue' : 'Payment due soon',
        body: body,
        severity: bucket == 'overdue' ? AlertSeverity.critical : AlertSeverity.info,
      ));
    }

    return alerts;
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
