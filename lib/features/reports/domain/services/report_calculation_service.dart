import '../../../../core/exceptions/app_exception.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/extensions/transaction_extensions.dart';
import '../../../transactions/domain/repositories/transactions_repository.dart';
import '../../../transactions/domain/services/account_balance_service.dart';
import '../../../transactions/domain/services/loan_service.dart';
import '../models/report_models.dart';

/// Builds every report's data from the app's existing repositories/services
/// only — the single source of truth both `PdfReportService` and
/// `ExcelReportService` read from, so a report's numbers can never drift
/// between the two export formats (or from the dashboard).
///
/// Follows the same date rules as the rest of the app: account balances and
/// expense reporting always use a transaction's actual `date`; monthly
/// income reporting always uses its `incomePeriod` (falling back to `date`'s
/// month). See CLAUDE.md "Income Reporting Period vs Money Movement Date".
///
/// Bounded queries only — large fetches (the transaction/expense/income
/// lists used for category breakdowns) are capped at [_largeFetchLimit],
/// matching the existing transaction-export precedent
/// (`transactions_modal.dart`), not an unbounded collection scan.
class ReportCalculationService {
  ReportCalculationService({
    required TransactionsRepository transactionsRepository,
    required AccountsRepository accountsRepository,
    required CategoriesRepository categoriesRepository,
    required LoanService loanService,
  })  : _transactionsRepository = transactionsRepository,
        _accountsRepository = accountsRepository,
        _categoriesRepository = categoriesRepository,
        _loanService = loanService;

  final TransactionsRepository _transactionsRepository;
  final AccountsRepository _accountsRepository;
  final CategoriesRepository _categoriesRepository;
  final LoanService _loanService;

  static const int _largeFetchLimit = 10000;

  Future<MonthlyReportData> monthlyReport(String userId, DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);

    final accounts = await _getAccounts(userId);
    final categoriesById = await _getCategoriesById(userId);

    final expenseTransactions = await _getExpenseTransactions(
      userId,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
    final incomeTransactions = await _getIncomeTransactions(
      userId,
      startPeriod: startOfMonth,
      endPeriod: endOfMonth,
    );

    final income = incomeTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final expense = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);

    final totalOwedToYou = await _loanService.getTotalOwedToYou(userId);
    final totalYouOwe = await _loanService.getTotalYouOwe(userId);

    return MonthlyReportData(
      month: startOfMonth,
      income: income,
      expense: expense,
      incomeTransactions: incomeTransactions,
      expenseTransactions: expenseTransactions,
      accounts: accounts,
      categoriesById: categoriesById,
      incomeByCategory: _categoryBreakdown(incomeTransactions, categoriesById),
      expenseByCategory: _categoryBreakdown(expenseTransactions, categoriesById),
      totalOwedToYou: totalOwedToYou,
      totalYouOwe: totalYouOwe,
    );
  }

  Future<TransactionReportData> transactionReport(
    String userId, {
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final result = await _transactionsRepository.getTransactions(
      userId,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      limit: _largeFetchLimit,
    );
    if (result.failure != null) throw ServerException(result.failure!.message);

    final accountsById = await _getAccountsById(userId);
    final categoriesById = await _getCategoriesById(userId);

    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in result.transactions) {
      if (t.type == TransactionType.income) totalIncome += t.amount;
      if (t.type == TransactionType.expense) totalExpense += t.amount;
    }

    return TransactionReportData(
      transactions: result.transactions,
      accountsById: accountsById,
      categoriesById: categoriesById,
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  /// The account's running balance over time, using only actual transaction
  /// dates — never `incomePeriod`. [endDate] bounds the fetch; history
  /// before [startDate] is still fetched (up to [endDate]) so the opening
  /// balance for the window is correct, then excluded from the displayed
  /// lines.
  Future<AccountStatementData> accountStatement(
    String userId,
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final accountResult = await _accountsRepository.getAccount(userId, accountId);
    if (accountResult.failure != null) {
      throw ServerException(accountResult.failure!.message);
    }
    final account = accountResult.account;
    if (account == null) {
      throw const NotFoundException('Account not found');
    }

    final historyResult = await _transactionsRepository.getAccountHistory(
      userId,
      accountId,
      endDate: endDate,
    );
    if (historyResult.failure != null) {
      throw ServerException(historyResult.failure!.message);
    }
    final history = historyResult.transactions; // ascending by date

    // Repayment direction depends on the linked loan's type; resolve each
    // distinct one once.
    final loanTypes = await _resolveLoanTypes(userId, history);

    var running = account.openingBalance;
    var windowOpeningBalance = account.openingBalance;
    final lines = <StatementLine>[];

    for (final transaction in history) {
      final linkedLoanId = transaction.metadata?['linkedLoanId'] as String?;
      final linkedLoanType = linkedLoanId == null ? null : loanTypes[linkedLoanId];
      final signed = AccountBalanceService.signedAmountFor(
        transaction,
        accountId,
        linkedLoanType: linkedLoanType,
      );

      final includeInWindow = startDate == null || !transaction.date.isBefore(startDate);
      if (!includeInWindow) {
        running += signed;
        windowOpeningBalance = running;
        continue;
      }

      running += signed;
      lines.add(StatementLine(
        transaction: transaction,
        description: transaction.displayTitle,
        debit: signed < 0 ? -signed : 0,
        credit: signed > 0 ? signed : 0,
        runningBalance: running,
      ));
    }

    return AccountStatementData(
      account: account,
      openingBalance: windowOpeningBalance,
      lines: lines,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<IncomeReportData> incomeReport(
    String userId, {
    DateTime? startPeriod,
    DateTime? endPeriod,
    String? accountId,
    String? categoryId,
  }) async {
    var transactions = await _getIncomeTransactions(
      userId,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
    );
    if (accountId != null) {
      transactions = transactions.where((t) => t.accountId == accountId).toList();
    }
    if (categoryId != null) {
      transactions = transactions.where((t) => t.categoryId == categoryId).toList();
    }
    transactions.sort((a, b) => b.date.compareTo(a.date));

    final accountsById = await _getAccountsById(userId);
    final categoriesById = await _getCategoriesById(userId);

    final rows = transactions
        .map((t) => IncomeReportRow(
              transaction: t,
              categoryName: categoriesById[t.categoryId]?.name ?? 'Uncategorized',
              accountName: accountsById[t.accountId]?.name ?? 'Unknown',
            ))
        .toList();

    return IncomeReportData(
      rows: rows,
      byCategory: _categoryBreakdown(transactions, categoriesById),
      total: transactions.fold<double>(0, (sum, t) => sum + t.amount),
      startPeriod: startPeriod,
      endPeriod: endPeriod,
    );
  }

  Future<ExpenseReportData> expenseReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? categoryId,
  }) async {
    final transactions = await _getExpenseTransactions(
      userId,
      startDate: startDate,
      endDate: endDate,
      accountId: accountId,
      categoryId: categoryId,
    );

    final accountsById = await _getAccountsById(userId);
    final categoriesById = await _getCategoriesById(userId);

    return ExpenseReportData(
      transactions: transactions,
      accountsById: accountsById,
      categoriesById: categoriesById,
      byCategory: _categoryBreakdown(transactions, categoriesById),
      total: transactions.fold<double>(0, (sum, t) => sum + t.amount),
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Expense is grouped by its actual date; income by its reporting period —
  /// the selected [startDate]..[endDate] window is read as a date range for
  /// expense and as a reporting-period range for income.
  Future<CategoryReportData> categoryReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final categoriesById = await _getCategoriesById(userId);

    final expenseTransactions = await _getExpenseTransactions(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
    final incomeTransactions = await _getIncomeTransactions(
      userId,
      startPeriod: startDate,
      endPeriod: endDate,
    );

    return CategoryReportData(
      incomeByCategory: _categoryBreakdown(incomeTransactions, categoriesById),
      expenseByCategory: _categoryBreakdown(expenseTransactions, categoriesById),
      totalIncome: incomeTransactions.fold<double>(0, (sum, t) => sum + t.amount),
      totalExpense: expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount),
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Active (not completed) loans/debts, as of now — not date-filtered,
  /// matching the dashboard's `LoansSummaryCard`.
  Future<LoanDebtReportData> loanDebtReport(String userId) async {
    final active = await _loanService.getActiveLoans(userId);

    // loanMetadata can be null if the stored metadata fails to parse; skip
    // those rather than crash the report.
    final owedToYou = <LoanDebtRow>[
      for (final t in active.loansGiven)
        if (t.loanMetadata != null) LoanDebtRow(transaction: t, metadata: t.loanMetadata!),
    ];
    final youOwe = <LoanDebtRow>[
      for (final t in active.loansTaken)
        if (t.loanMetadata != null) LoanDebtRow(transaction: t, metadata: t.loanMetadata!),
    ];

    return LoanDebtReportData(owedToYou: owedToYou, youOwe: youOwe);
  }

  Future<AnnualReportData> annualReport(String userId, int year) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59, 999);

    final monthlyResult = await _transactionsRepository.getMonthlyTotals(
      userId,
      startDate: startOfYear,
      endDate: endOfYear,
    );
    if (monthlyResult.failure != null) {
      throw ServerException(monthlyResult.failure!.message);
    }

    final monthly = <MonthlyBreakdownRow>[
      for (var m = 1; m <= 12; m++)
        MonthlyBreakdownRow(
          month: DateTime(year, m),
          income: monthlyResult.totals[DateTime(year, m)]?.income ?? 0,
          expense: monthlyResult.totals[DateTime(year, m)]?.expense ?? 0,
        ),
    ];

    final categoriesById = await _getCategoriesById(userId);
    final expenseTransactions = await _getExpenseTransactions(
      userId,
      startDate: startOfYear,
      endDate: endOfYear,
    );
    final incomeTransactions = await _getIncomeTransactions(
      userId,
      startPeriod: startOfYear,
      endPeriod: endOfYear,
    );

    final accounts = await _getAccounts(userId);
    final accountsById = {for (final a in accounts) a.id: a};
    final loans = await loanDebtReport(userId);

    return AnnualReportData(
      year: year,
      monthly: monthly,
      incomeTransactions: incomeTransactions,
      expenseTransactions: expenseTransactions,
      accountsById: accountsById,
      categoriesById: categoriesById,
      incomeByCategory: _categoryBreakdown(incomeTransactions, categoriesById),
      expenseByCategory: _categoryBreakdown(expenseTransactions, categoriesById),
      accounts: accounts,
      loans: loans,
    );
  }

  // ---- shared helpers ----

  List<CategoryBreakdownRow> _categoryBreakdown(
    Iterable<TransactionModel> transactions,
    Map<String, CategoryModel> categoriesById,
  ) {
    final counts = <String, int>{};
    final totals = <String, double>{};
    for (final t in transactions) {
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }
    final grandTotal = totals.values.fold<double>(0, (a, b) => a + b);

    final rows = totals.entries
        .map((entry) => CategoryBreakdownRow(
              categoryId: entry.key,
              categoryName: categoriesById[entry.key]?.name ?? 'Uncategorized',
              transactionCount: counts[entry.key] ?? 0,
              total: entry.value,
              percentage: grandTotal <= 0 ? 0 : (entry.value / grandTotal) * 100,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  Future<List<TransactionModel>> _getExpenseTransactions(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? categoryId,
  }) async {
    final result = await _transactionsRepository.getTransactions(
      userId,
      type: TransactionType.expense,
      accountId: accountId,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      limit: _largeFetchLimit,
    );
    if (result.failure != null) throw ServerException(result.failure!.message);
    return result.transactions;
  }

  Future<List<TransactionModel>> _getIncomeTransactions(
    String userId, {
    DateTime? startPeriod,
    DateTime? endPeriod,
  }) async {
    final result = await _transactionsRepository.getIncomeTransactions(
      userId,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
    );
    if (result.failure != null) throw ServerException(result.failure!.message);
    return result.transactions;
  }

  Future<List<AccountModel>> _getAccounts(String userId) async {
    final result = await _accountsRepository.getAccounts(userId);
    if (result.failure != null) throw ServerException(result.failure!.message);
    return result.accounts;
  }

  Future<Map<String, AccountModel>> _getAccountsById(String userId) async {
    final accounts = await _getAccounts(userId);
    return {for (final a in accounts) a.id: a};
  }

  Future<Map<String, CategoryModel>> _getCategoriesById(String userId) async {
    final result = await _categoriesRepository.getCategories(userId);
    if (result.failure != null) throw ServerException(result.failure!.message);
    return {for (final c in result.categories) c.id: c};
  }

  /// The loan type (given/taken) for each distinct `linkedLoanId` among
  /// [transactions]' `loanRepayment` entries — needed to sign a repayment's
  /// balance effect (see `AccountBalanceService.signedAmountFor`).
  Future<Map<String, TransactionType>> _resolveLoanTypes(
    String userId,
    List<TransactionModel> transactions,
  ) async {
    final loanIds = <String>{
      for (final t in transactions)
        if (t.type == TransactionType.loanRepayment)
          if (t.metadata?['linkedLoanId'] is String) t.metadata!['linkedLoanId'] as String,
    };
    if (loanIds.isEmpty) return {};

    final types = <String, TransactionType>{};
    for (final loanId in loanIds) {
      final result = await _transactionsRepository.getTransaction(userId, loanId);
      final loan = result.transaction;
      if (loan != null) types[loanId] = loan.type;
    }
    return types;
  }
}
