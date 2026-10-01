/// The 8 report types the Reports hub and contextual export actions offer.
/// Each maps to one `ReportCalculationService` method and one builder method
/// on `PdfReportService`/`ExcelReportService`.
enum ReportType {
  monthly,
  transactionStatement,
  accountStatement,
  income,
  expense,
  category,
  loansDebts,
  annual;

  String get displayName {
    switch (this) {
      case ReportType.monthly:
        return 'Monthly Report';
      case ReportType.transactionStatement:
        return 'Transaction Statement';
      case ReportType.accountStatement:
        return 'Account Statement';
      case ReportType.income:
        return 'Income Report';
      case ReportType.expense:
        return 'Expense Report';
      case ReportType.category:
        return 'Category Report';
      case ReportType.loansDebts:
        return 'Loans & Debts Report';
      case ReportType.annual:
        return 'Annual Report';
    }
  }

  String get description {
    switch (this) {
      case ReportType.monthly:
        return 'Income, expense and account balances for a month.';
      case ReportType.transactionStatement:
        return 'A detailed list of transactions for a date range and filters.';
      case ReportType.accountStatement:
        return 'A single account\'s running balance over time.';
      case ReportType.income:
        return 'Income grouped by the month it\'s reported under.';
      case ReportType.expense:
        return 'Expenses with a category breakdown.';
      case ReportType.category:
        return 'Income and expense totals by category.';
      case ReportType.loansDebts:
        return 'Money owed to you and money you owe.';
      case ReportType.annual:
        return 'A full year\'s income, expense and category breakdown.';
    }
  }

  /// Whether this report's filters include an account picker.
  bool get supportsAccountFilter =>
      this == ReportType.transactionStatement ||
      this == ReportType.income ||
      this == ReportType.expense;

  /// Whether this report's filters include a category picker.
  bool get supportsCategoryFilter =>
      this == ReportType.transactionStatement ||
      this == ReportType.income ||
      this == ReportType.expense;

  /// Whether this report's filters include a transaction-type picker.
  bool get supportsTypeFilter => this == ReportType.transactionStatement;

  /// Whether this report needs a date range (as opposed to a single month,
  /// a single account, or no date filter at all).
  bool get usesDateRange =>
      this == ReportType.transactionStatement ||
      this == ReportType.accountStatement ||
      this == ReportType.income ||
      this == ReportType.expense ||
      this == ReportType.category;

  /// Whether this report is scoped to a single calendar month (picked with
  /// a month/year control instead of a date range).
  bool get usesSingleMonth => this == ReportType.monthly;

  /// Whether this report is scoped to a single year.
  bool get usesYear => this == ReportType.annual;

  /// Whether this report needs a specific account selected (not optional).
  bool get requiresAccount => this == ReportType.accountStatement;
}
