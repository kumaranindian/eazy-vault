import 'package:freezed_annotation/freezed_annotation.dart';

part 'loan_metadata.freezed.dart';
part 'loan_metadata.g.dart';

enum LoanStatus {
  pending,
  partial,
  completed,
  overdue;

  String get displayName {
    switch (this) {
      case LoanStatus.pending:
        return 'Pending';
      case LoanStatus.partial:
        return 'Partially Paid';
      case LoanStatus.completed:
        return 'Completed';
      case LoanStatus.overdue:
        return 'Overdue';
    }
  }
}

@freezed
class LoanMetadata with _$LoanMetadata {
  const factory LoanMetadata({
    String? partyName, // Lender or Borrower name
    String? partyContact, // Phone or email
    DateTime? dueDate,
    double? interestRate,
    @Default(LoanStatus.pending) LoanStatus status,
    double? originalAmount,
    double? remainingAmount,
    String? notes,
    List<LoanInstallment>? installments,
    String? linkedLoanId, // For linking repayments to original loan
  }) = _LoanMetadata;

  factory LoanMetadata.fromJson(Map<String, dynamic> json) =>
      _$LoanMetadataFromJson(json);
}

@freezed
class LoanInstallment with _$LoanInstallment {
  const factory LoanInstallment({
    required DateTime dueDate,
    required double amount,
    @Default(false) bool isPaid,
    DateTime? paidDate,
    String? transactionId,
  }) = _LoanInstallment;

  factory LoanInstallment.fromJson(Map<String, dynamic> json) =>
      _$LoanInstallmentFromJson(json);
}

@freezed
class TransferMetadata with _$TransferMetadata {
  const factory TransferMetadata({
    required String fromAccountId,
    required String toAccountId,
    String? notes,
  }) = _TransferMetadata;

  factory TransferMetadata.fromJson(Map<String, dynamic> json) =>
      _$TransferMetadataFromJson(json);
}
