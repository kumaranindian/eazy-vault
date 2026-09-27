enum AccountType {
  cash,
  savings,
  current,
  upi,
  creditCard;

  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.savings:
        return 'Savings Account';
      case AccountType.current:
        return 'Current Account';
      case AccountType.upi:
        return 'UPI';
      case AccountType.creditCard:
        return 'Credit Card';
    }
  }

  String get icon {
    switch (this) {
      case AccountType.cash:
        return '💵';
      case AccountType.savings:
        return '🏦';
      case AccountType.current:
        return '🏢';
      case AccountType.upi:
        return '📱';
      case AccountType.creditCard:
        return '💳';
    }
  }
}
