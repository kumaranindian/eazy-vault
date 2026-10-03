import 'package:eazyvault/features/budgets/data/models/budget_model.dart';
import 'package:eazyvault/features/budgets/presentation/providers/budget_progress_provider.dart';
import 'package:eazyvault/features/categories/data/models/category_model.dart';
import 'package:eazyvault/features/categories/domain/enums/category_type.dart';
import 'package:eazyvault/features/notifications/domain/models/app_alert.dart';
import 'package:eazyvault/features/notifications/domain/services/alert_evaluator.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/models/loan_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 3, 15);

  BudgetModel budget({double amount = 1000}) => BudgetModel(
        id: 'budget-1',
        categoryId: 'category-1',
        amount: amount,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

  CategoryModel category() => CategoryModel(
        id: 'category-1',
        name: 'Food',
        type: CategoryType.expense,
        color: 0xFFFF0000,
        icon: '🍔',
        isDefault: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

  TransactionModel loan({
    required DateTime dueDate,
    LoanStatus status = LoanStatus.pending,
  }) =>
      TransactionModel(
        id: 'loan-1',
        type: TransactionType.loanGiven,
        amount: 500,
        accountId: 'account-1',
        categoryId: 'loan',
        date: now,
        metadata: LoanMetadata(
          partyName: 'Alex',
          dueDate: dueDate,
          status: status,
        ).toJson(),
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-1',
      );

  group('evaluateBudgetAlerts', () {
    test('no alert below the lowest threshold', () {
      final progress = BudgetProgress(budget: budget(), category: category(), spent: 750);
      expect(AlertEvaluator.evaluateBudgetAlerts([progress], now: now), isEmpty);
    });

    test('warns at 80% and again (replacing, not stacking) at 90%', () {
      final at80 = BudgetProgress(budget: budget(), category: category(), spent: 800);
      final alerts80 = AlertEvaluator.evaluateBudgetAlerts([at80], now: now);
      expect(alerts80, hasLength(1));
      expect(alerts80.single.key, endsWith(':80'));
      expect(alerts80.single.severity, AlertSeverity.warning);

      final at95 = BudgetProgress(budget: budget(), category: category(), spent: 950);
      final alerts95 = AlertEvaluator.evaluateBudgetAlerts([at95], now: now);
      expect(alerts95, hasLength(1));
      expect(alerts95.single.key, endsWith(':90'));
    });

    test('is critical once the budget is fully used', () {
      final overBudget = BudgetProgress(budget: budget(), category: category(), spent: 1200);
      final alerts = AlertEvaluator.evaluateBudgetAlerts([overBudget], now: now);
      expect(alerts.single.key, endsWith(':100'));
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('dedup key changes between calendar months', () {
      final progress = BudgetProgress(budget: budget(), category: category(), spent: 900);
      final march = AlertEvaluator.evaluateBudgetAlerts([progress], now: DateTime(2026, 3, 15));
      final april = AlertEvaluator.evaluateBudgetAlerts([progress], now: DateTime(2026, 4, 1));
      expect(march.single.key, isNot(equals(april.single.key)));
    });
  });

  group('evaluateBillAlerts', () {
    test('alerts for overdue, today, tomorrow and 3-days-out, but not other gaps', () {
      final loans = [
        loan(dueDate: now.subtract(const Duration(days: 2))),
        loan(dueDate: now),
        loan(dueDate: now.add(const Duration(days: 1))),
        loan(dueDate: now.add(const Duration(days: 3))),
        loan(dueDate: now.add(const Duration(days: 10))),
      ];

      final alerts = AlertEvaluator.evaluateBillAlerts(loans, now: now);
      expect(alerts, hasLength(4));
      expect(alerts[0].severity, AlertSeverity.critical);
      expect(alerts[0].key, contains('overdue'));
    });

    test('skips completed loans even if overdue', () {
      final loans = [
        loan(dueDate: now.subtract(const Duration(days: 5)), status: LoanStatus.completed),
      ];
      expect(AlertEvaluator.evaluateBillAlerts(loans, now: now), isEmpty);
    });
  });
}
