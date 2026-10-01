import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../models/loan_metadata.dart';
import '../utils/income_period.dart';

extension TransactionModelExtensions on TransactionModel {
  // Check if transaction is a loan type
  bool get isLoan => type.isLoanType;

  /// The `YYYY-MM` month this income is reported under on monthly
  /// dashboards: the explicit [TransactionModel.incomePeriod] when set,
  /// otherwise the month of [TransactionModel.date] — the same fallback used
  /// for income written before this field existed. Meaningful for income
  /// only; every other type reports under its own transaction date.
  String get effectiveIncomePeriod => incomePeriod ?? IncomePeriod.of(date);

  /// [effectiveIncomePeriod] as the first instant of that month.
  DateTime get incomeReportingMonth => IncomePeriod.toMonth(effectiveIncomePeriod);

  /// Whether this income's reporting period was explicitly chosen to differ
  /// from the month it was actually credited — worth calling out in the UI.
  bool get hasDistinctIncomePeriod =>
      type == TransactionType.income && effectiveIncomePeriod != IncomePeriod.of(date);

  // Check if transaction is a transfer
  bool get isTransfer => type == TransactionType.transfer;

  // Get loan metadata if exists
  LoanMetadata? get loanMetadata {
    if (metadata == null || !isLoan) return null;
    try {
      return LoanMetadata.fromJson(metadata!);
    } catch (e) {
      return null;
    }
  }

  // Get transfer metadata if exists
  TransferMetadata? get transferMetadata {
    if (metadata == null || !isTransfer) return null;
    try {
      return TransferMetadata.fromJson(metadata!);
    } catch (e) {
      return null;
    }
  }

  /// Signed effect on the user's money, for summaries: positive for money in
  /// (income, loan taken), negative for money out (expense, loan given), zero
  /// for transfers between the user's own accounts. A repayment's direction
  /// depends on its linked loan, which isn't available here, so it counts 0.
  double get cashFlow {
    switch (type) {
      case TransactionType.income:
      case TransactionType.loanTaken:
        return amount;
      case TransactionType.expense:
      case TransactionType.loanGiven:
        return -amount;
      case TransactionType.transfer:
      case TransactionType.loanRepayment:
        return 0;
    }
  }

  // Get display title for transaction
  String get displayTitle {
    if (isTransfer && transferMetadata != null) {
      return 'Transfer';
    }
    if (isLoan && loanMetadata != null) {
      return loanMetadata!.partyName ?? type.displayName;
    }
    return vendor ?? description ?? type.displayName;
  }

  // Get subtitle for transaction
  String? get displaySubtitle {
    if (isTransfer && transferMetadata != null) {
      return transferMetadata!.notes;
    }
    if (isLoan && loanMetadata != null) {
      final status = loanMetadata!.status.displayName;
      final remaining = loanMetadata!.remainingAmount;
      if (remaining != null && remaining > 0) {
        return '$status - Remaining: ₹${remaining.toStringAsFixed(2)}';
      }
      return status;
    }
    return description;
  }

  // Check if loan is overdue
  bool get isOverdue {
    if (!isLoan) return false;
    final loan = loanMetadata;
    if (loan == null || loan.dueDate == null) return false;
    return loan.status != LoanStatus.completed &&
        DateTime.now().isAfter(loan.dueDate!);
  }

  // Get days until due (for loans)
  int? get daysUntilDue {
    if (!isLoan) return null;
    final loan = loanMetadata;
    if (loan == null || loan.dueDate == null) return null;
    return loan.dueDate!.difference(DateTime.now()).inDays;
  }

  // Calculate total interest (for loans with interest rate)
  double? get totalInterest {
    if (!isLoan) return null;
    final loan = loanMetadata;
    if (loan == null || loan.interestRate == null) return null;
    final principal = loan.originalAmount ?? amount;
    return principal * (loan.interestRate! / 100);
  }

  // Get completion percentage for loans
  double? get completionPercentage {
    if (!isLoan) return null;
    final loan = loanMetadata;
    if (loan == null || loan.originalAmount == null) return null;
    final paid = loan.originalAmount! - (loan.remainingAmount ?? 0);
    return (paid / loan.originalAmount!) * 100;
  }
}
