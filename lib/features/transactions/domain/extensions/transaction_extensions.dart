import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../models/loan_metadata.dart';

extension TransactionModelExtensions on TransactionModel {
  // Check if transaction is a loan type
  bool get isLoan => type.isLoanType;

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
