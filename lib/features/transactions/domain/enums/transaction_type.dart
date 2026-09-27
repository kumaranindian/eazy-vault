enum TransactionType {
  income,
  expense,
  transfer,
  loanGiven,
  loanTaken,
  loanRepayment;

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.loanGiven:
        return 'Loan Given';
      case TransactionType.loanTaken:
        return 'Loan Taken';
      case TransactionType.loanRepayment:
        return 'Loan Repayment';
    }
  }

  String get icon {
    switch (this) {
      case TransactionType.income:
        return '📈';
      case TransactionType.expense:
        return '📉';
      case TransactionType.transfer:
        return '🔄';
      case TransactionType.loanGiven:
        return '💸';
      case TransactionType.loanTaken:
        return '🤝';
      case TransactionType.loanRepayment:
        return '💰';
    }
  }

  String get description {
    switch (this) {
      case TransactionType.income:
        return 'Money received';
      case TransactionType.expense:
        return 'Money spent';
      case TransactionType.transfer:
        return 'Transfer between accounts';
      case TransactionType.loanGiven:
        return 'Money lent to someone';
      case TransactionType.loanTaken:
        return 'Money borrowed from someone';
      case TransactionType.loanRepayment:
        return 'Loan payment received or made';
    }
  }

  bool get isLoanType {
    return this == TransactionType.loanGiven ||
        this == TransactionType.loanTaken ||
        this == TransactionType.loanRepayment;
  }

  bool get affectsBalance {
    return this != TransactionType.transfer;
  }
}
