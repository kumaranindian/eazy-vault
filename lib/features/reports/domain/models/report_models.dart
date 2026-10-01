import '../../../accounts/data/models/account_model.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/extensions/transaction_extensions.dart';
import '../../../transactions/domain/models/loan_metadata.dart';

/// A single category's contribution to a report: how many transactions, the
/// total, and the share of the report's overall total they are.
class CategoryBreakdownRow {
  const CategoryBreakdownRow({
    required this.categoryId,
    required this.categoryName,
    required this.transactionCount,
    required this.total,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final int transactionCount;
  final double total;

  /// 0-100.
  final double percentage;
}

/// One calendar month's income/expense, for annual/trend reports.
class MonthlyBreakdownRow {
  const MonthlyBreakdownRow({
    required this.month,
    required this.income,
    required this.expense,
  });

  /// The first day of the month.
  final DateTime month;
  final double income;
  final double expense;

  double get netSavings => income - expense;
}

/// One line of an account statement: the transaction plus its effect and
/// running balance. [debit] XOR [credit] is non-zero, never both.
class StatementLine {
  const StatementLine({
    required this.transaction,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final TransactionModel transaction;
  final String description;
  final double debit;
  final double credit;
  final double runningBalance;
}

class MonthlyReportData {
  const MonthlyReportData({
    required this.month,
    required this.income,
    required this.expense,
    required this.incomeTransactions,
    required this.expenseTransactions,
    required this.accounts,
    required this.categoriesById,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.totalOwedToYou,
    required this.totalYouOwe,
  });

  final DateTime month;
  final double income;
  final double expense;
  final List<TransactionModel> incomeTransactions;
  final List<TransactionModel> expenseTransactions;
  final List<AccountModel> accounts;
  final Map<String, CategoryModel> categoriesById;
  final List<CategoryBreakdownRow> incomeByCategory;
  final List<CategoryBreakdownRow> expenseByCategory;
  final double totalOwedToYou;
  final double totalYouOwe;

  int get transactionCount => incomeTransactions.length + expenseTransactions.length;
  double get netSavings => income - expense;
  double get totalBalance => accounts.fold<double>(0, (sum, a) => sum + a.currentBalance);
}

class TransactionReportData {
  const TransactionReportData({
    required this.transactions,
    required this.accountsById,
    required this.categoriesById,
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
  });

  final List<TransactionModel> transactions;
  final Map<String, AccountModel> accountsById;
  final Map<String, CategoryModel> categoriesById;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalIncome;
  final double totalExpense;

  double get net => totalIncome - totalExpense;
}

class AccountStatementData {
  const AccountStatementData({
    required this.account,
    required this.openingBalance,
    required this.lines,
    required this.startDate,
    required this.endDate,
  });

  final AccountModel account;

  /// The account's balance just before [startDate] (or the account's own
  /// `openingBalance` when [startDate] is null — the whole history).
  final double openingBalance;
  final List<StatementLine> lines;
  final DateTime? startDate;
  final DateTime? endDate;

  double get closingBalance => lines.isEmpty ? openingBalance : lines.last.runningBalance;
  double get totalDebits => lines.fold<double>(0, (sum, l) => sum + l.debit);
  double get totalCredits => lines.fold<double>(0, (sum, l) => sum + l.credit);
}

class IncomeReportRow {
  const IncomeReportRow({
    required this.transaction,
    required this.categoryName,
    required this.accountName,
  });

  final TransactionModel transaction;
  final String categoryName;
  final String accountName;

  /// Actual money-movement date — never replaced by [incomeForMonth].
  DateTime get creditedDate => transaction.date;
  DateTime get incomeForMonth => transaction.incomeReportingMonth;
  double get amount => transaction.amount;
}

class IncomeReportData {
  const IncomeReportData({
    required this.rows,
    required this.byCategory,
    required this.total,
    required this.startPeriod,
    required this.endPeriod,
  });

  final List<IncomeReportRow> rows;
  final List<CategoryBreakdownRow> byCategory;
  final double total;
  final DateTime? startPeriod;
  final DateTime? endPeriod;
}

class ExpenseReportData {
  const ExpenseReportData({
    required this.transactions,
    required this.accountsById,
    required this.categoriesById,
    required this.byCategory,
    required this.total,
    required this.startDate,
    required this.endDate,
  });

  final List<TransactionModel> transactions;
  final Map<String, AccountModel> accountsById;
  final Map<String, CategoryModel> categoriesById;
  final List<CategoryBreakdownRow> byCategory;
  final double total;
  final DateTime? startDate;
  final DateTime? endDate;
}

class CategoryReportData {
  const CategoryReportData({
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.totalIncome,
    required this.totalExpense,
    required this.startDate,
    required this.endDate,
  });

  final List<CategoryBreakdownRow> incomeByCategory;
  final List<CategoryBreakdownRow> expenseByCategory;
  final double totalIncome;
  final double totalExpense;
  final DateTime? startDate;
  final DateTime? endDate;
}

class LoanDebtRow {
  const LoanDebtRow({
    required this.transaction,
    required this.metadata,
  });

  final TransactionModel transaction;
  final LoanMetadata metadata;

  String get partyName => metadata.partyName ?? 'Unknown';
  double get remainingAmount => metadata.remainingAmount ?? transaction.amount;
  LoanStatus get status => metadata.status;
  DateTime? get dueDate => metadata.dueDate;
}

class LoanDebtReportData {
  const LoanDebtReportData({
    required this.owedToYou,
    required this.youOwe,
  });

  final List<LoanDebtRow> owedToYou;
  final List<LoanDebtRow> youOwe;

  double get totalOwedToYou => owedToYou.fold<double>(0, (sum, r) => sum + r.remainingAmount);
  double get totalYouOwe => youOwe.fold<double>(0, (sum, r) => sum + r.remainingAmount);
  double get netPosition => totalOwedToYou - totalYouOwe;
}

class AnnualReportData {
  const AnnualReportData({
    required this.year,
    required this.monthly,
    required this.incomeTransactions,
    required this.expenseTransactions,
    required this.accountsById,
    required this.categoriesById,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.accounts,
    required this.loans,
  });

  final int year;
  final List<MonthlyBreakdownRow> monthly;
  final List<TransactionModel> incomeTransactions;
  final List<TransactionModel> expenseTransactions;
  final Map<String, AccountModel> accountsById;
  final Map<String, CategoryModel> categoriesById;
  final List<CategoryBreakdownRow> incomeByCategory;
  final List<CategoryBreakdownRow> expenseByCategory;
  final List<AccountModel> accounts;
  final LoanDebtReportData loans;

  double get totalIncome => monthly.fold<double>(0, (sum, m) => sum + m.income);
  double get totalExpense => monthly.fold<double>(0, (sum, m) => sum + m.expense);
  double get netSavings => totalIncome - totalExpense;
  double get totalBalance => accounts.fold<double>(0, (sum, a) => sum + a.currentBalance);
}
