import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../accounts/data/models/account_model.dart';
import '../../../transactions/domain/extensions/transaction_extensions.dart';
import '../../domain/models/report_models.dart';

/// Builds a real `.xlsx` workbook for every report type except "Transaction
/// Statement" (which reuses `TransactionExportService.buildExcel` directly —
/// a flat transaction list is already exactly what that builds). Amounts are
/// written as numeric cells (`DoubleCellValue`, 2-decimal number format, no
/// ₹ symbol) and dates as real Excel dates, per the project's Excel export
/// requirements, never as formatted strings.
class ExcelReportService {
  const ExcelReportService();

  static final _headerStyle = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('FF10B981'),
    fontColorHex: ExcelColor.white,
  );
  static final _totalsStyle = CellStyle(bold: true);
  static final _amountStyle = CellStyle(numberFormat: NumFormat.standard_2);
  static final _amountTotalsStyle = CellStyle(bold: true, numberFormat: NumFormat.standard_2);

  Uint8List buildMonthlyReport(MonthlyReportData data) {
    final excel = Excel.createExcel();

    final summary = _sheet(excel, 'Summary', isFirst: true);
    _writeHeader(summary, const ['Metric', 'Value']);
    _appendRow(summary, [_text('Month'), _text(_monthLabel(data.month))]);
    _appendAmountRow(summary, 'Total Income', data.income);
    _appendAmountRow(summary, 'Total Expense', data.expense);
    _appendAmountRow(summary, 'Net Savings', data.netSavings);
    _appendAmountRow(summary, 'Total Balance', data.totalBalance);
    _appendAmountRow(summary, 'Owed to You', data.totalOwedToYou);
    _appendAmountRow(summary, 'You Owe', data.totalYouOwe);
    _appendRow(summary, [_text('Transactions'), _int(data.transactionCount)]);

    final income = _sheet(excel, 'Income');
    _writeHeader(income, const ['Credited Date', 'Income For', 'Category', 'Account', 'Description', 'Amount']);
    for (final t in data.incomeTransactions) {
      _appendRow(income, [
        _date(t.date),
        _text(_monthLabel(t.incomeReportingMonth)),
        _text(data.categoriesById[t.categoryId]?.name ?? 'Uncategorized'),
        _text(_accountName(data.accounts, t.accountId)),
        _text(t.description ?? t.vendor ?? ''),
        _amount(t.amount),
      ]);
      _styleLastAmountCell(income, 5);
    }

    final expenses = _sheet(excel, 'Expenses');
    _writeHeader(expenses, const ['Date', 'Category', 'Account', 'Description', 'Amount']);
    for (final t in data.expenseTransactions) {
      _appendRow(expenses, [
        _date(t.date),
        _text(data.categoriesById[t.categoryId]?.name ?? 'Uncategorized'),
        _text(_accountName(data.accounts, t.accountId)),
        _text(t.description ?? t.vendor ?? ''),
        _amount(t.amount),
      ]);
      _styleLastAmountCell(expenses, 4);
    }

    final accounts = _sheet(excel, 'Accounts');
    _writeHeader(accounts, const ['Account', 'Type', 'Opening Balance', 'Current Balance']);
    for (final account in data.accounts) {
      _appendRow(accounts, [
        _text(account.name),
        _text(account.type.displayName),
        _amount(account.openingBalance),
        _amount(account.currentBalance),
      ]);
      _styleLastAmountCell(accounts, 2);
      _styleLastAmountCell(accounts, 3);
    }

    _autoFit(summary, 2);
    _autoFit(income, 6);
    _autoFit(expenses, 5);
    _autoFit(accounts, 4);

    return _finish(excel);
  }

  Uint8List buildAccountStatement(AccountStatementData data) {
    final excel = Excel.createExcel();
    final sheet = _sheet(excel, 'Statement', isFirst: true);

    _appendRow(sheet, [_text('Account'), _text(data.account.name)]);
    _appendRow(sheet, [_text('Opening Balance'), _amount(data.openingBalance)]);
    _styleLastAmountCell(sheet, 1);
    sheet.appendRow([]);

    _writeHeader(sheet, const ['Date', 'Description', 'Category', 'Debit', 'Credit', 'Balance']);
    for (final line in data.lines) {
      _appendRow(sheet, [
        _date(line.transaction.date),
        _text(line.description),
        _text(line.transaction.categoryId),
        line.debit > 0 ? _amount(line.debit) : _text(''),
        line.credit > 0 ? _amount(line.credit) : _text(''),
        _amount(line.runningBalance),
      ]);
      _styleLastAmountCell(sheet, 3);
      _styleLastAmountCell(sheet, 4);
      _styleLastAmountCell(sheet, 5);
    }

    _autoFit(sheet, 6);
    return _finish(excel);
  }

  Uint8List buildIncomeReport(IncomeReportData data) {
    final excel = Excel.createExcel();
    final sheet = _sheet(excel, 'Income', isFirst: true);

    _writeHeader(sheet, const ['Credited Date', 'Income For', 'Category', 'Account', 'Description', 'Amount']);
    for (final row in data.rows) {
      _appendRow(sheet, [
        _date(row.creditedDate),
        _text(_monthLabel(row.incomeForMonth)),
        _text(row.categoryName),
        _text(row.accountName),
        _text(row.transaction.description ?? row.transaction.vendor ?? ''),
        _amount(row.amount),
      ]);
      _styleLastAmountCell(sheet, 5);
    }
    _appendTotalsRow(sheet, 'Total', 5, data.total);

    final categories = _sheet(excel, 'Categories');
    _writeCategoryBreakdown(categories, data.byCategory);

    _autoFit(sheet, 6);
    _autoFit(categories, 4);
    return _finish(excel);
  }

  Uint8List buildExpenseReport(ExpenseReportData data) {
    final excel = Excel.createExcel();
    final sheet = _sheet(excel, 'Expenses', isFirst: true);

    _writeHeader(sheet, const ['Date', 'Category', 'Account', 'Description', 'Amount']);
    for (final t in data.transactions) {
      _appendRow(sheet, [
        _date(t.date),
        _text(data.categoriesById[t.categoryId]?.name ?? 'Uncategorized'),
        _text(data.accountsById[t.accountId]?.name ?? 'Unknown'),
        _text(t.description ?? t.vendor ?? ''),
        _amount(t.amount),
      ]);
      _styleLastAmountCell(sheet, 4);
    }
    _appendTotalsRow(sheet, 'Total', 4, data.total);

    final categories = _sheet(excel, 'Categories');
    _writeCategoryBreakdown(categories, data.byCategory);

    _autoFit(sheet, 5);
    _autoFit(categories, 4);
    return _finish(excel);
  }

  Uint8List buildCategoryReport(CategoryReportData data) {
    final excel = Excel.createExcel();

    final expense = _sheet(excel, 'Expense Categories', isFirst: true);
    _writeCategoryBreakdown(expense, data.expenseByCategory);

    final income = _sheet(excel, 'Income Categories');
    _writeCategoryBreakdown(income, data.incomeByCategory);

    _autoFit(expense, 4);
    _autoFit(income, 4);
    return _finish(excel);
  }

  Uint8List buildLoanDebtReport(LoanDebtReportData data) {
    final excel = Excel.createExcel();

    void writeLoans(Sheet sheet, List<LoanDebtRow> rows) {
      _writeHeader(sheet, const ['Person', 'Amount', 'Status', 'Due Date', 'Notes']);
      for (final row in rows) {
        _appendRow(sheet, [
          _text(row.partyName),
          _amount(row.remainingAmount),
          _text(row.status.displayName),
          row.dueDate == null ? _text('') : _date(row.dueDate!),
          _text(row.metadata.notes ?? ''),
        ]);
        _styleLastAmountCell(sheet, 1);
      }
    }

    final owedToYou = _sheet(excel, 'Owed to You', isFirst: true);
    writeLoans(owedToYou, data.owedToYou);
    _appendTotalsRow(owedToYou, 'Total', 1, data.totalOwedToYou);

    final youOwe = _sheet(excel, 'You Owe');
    writeLoans(youOwe, data.youOwe);
    _appendTotalsRow(youOwe, 'Total', 1, data.totalYouOwe);

    _autoFit(owedToYou, 5);
    _autoFit(youOwe, 5);
    return _finish(excel);
  }

  Uint8List buildAnnualReport(AnnualReportData data) {
    final excel = Excel.createExcel();

    final summary = _sheet(excel, 'Summary', isFirst: true);
    _writeHeader(summary, const ['Metric', 'Value']);
    _appendAmountRow(summary, 'Total Income', data.totalIncome);
    _appendAmountRow(summary, 'Total Expense', data.totalExpense);
    _appendAmountRow(summary, 'Net Savings', data.netSavings);
    _appendAmountRow(summary, 'Total Balance', data.totalBalance);
    _appendAmountRow(summary, 'Owed to You', data.loans.totalOwedToYou);
    _appendAmountRow(summary, 'You Owe', data.loans.totalYouOwe);

    final monthly = _sheet(excel, 'Monthly Summary');
    _writeHeader(monthly, const ['Month', 'Income', 'Expense', 'Net Savings']);
    for (final m in data.monthly) {
      _appendRow(monthly, [
        _text(_monthLabel(m.month)),
        _amount(m.income),
        _amount(m.expense),
        _amount(m.netSavings),
      ]);
      _styleLastAmountCell(monthly, 1);
      _styleLastAmountCell(monthly, 2);
      _styleLastAmountCell(monthly, 3);
    }
    _appendTotalsRow(monthly, 'Total', 1, data.totalIncome, extra: [_amount(data.totalExpense), _amount(data.netSavings)]);

    final income = _sheet(excel, 'Income');
    _writeHeader(income, const ['Credited Date', 'Income For', 'Category', 'Description', 'Amount']);
    for (final t in data.incomeTransactions) {
      _appendRow(income, [
        _date(t.date),
        _text(_monthLabel(t.incomeReportingMonth)),
        _text(data.categoriesById[t.categoryId]?.name ?? 'Uncategorized'),
        _text(t.description ?? t.vendor ?? ''),
        _amount(t.amount),
      ]);
      _styleLastAmountCell(income, 4);
    }

    final expenses = _sheet(excel, 'Expenses');
    _writeHeader(expenses, const ['Date', 'Category', 'Description', 'Amount']);
    for (final t in data.expenseTransactions) {
      _appendRow(expenses, [
        _date(t.date),
        _text(data.categoriesById[t.categoryId]?.name ?? 'Uncategorized'),
        _text(t.description ?? t.vendor ?? ''),
        _amount(t.amount),
      ]);
      _styleLastAmountCell(expenses, 3);
    }

    final categories = _sheet(excel, 'Categories');
    _writeRowLabel(categories, 'Income Categories');
    _writeCategoryBreakdown(categories, data.incomeByCategory, blankRowAfterHeader: false);
    categories.appendRow([]);
    _writeRowLabel(categories, 'Expense Categories');
    _writeCategoryBreakdown(categories, data.expenseByCategory, blankRowAfterHeader: false);

    final accounts = _sheet(excel, 'Accounts');
    _writeHeader(accounts, const ['Account', 'Type', 'Current Balance']);
    for (final account in data.accounts) {
      _appendRow(accounts, [_text(account.name), _text(account.type.displayName), _amount(account.currentBalance)]);
      _styleLastAmountCell(accounts, 2);
    }

    final loans = _sheet(excel, 'Loans & Debts');
    _writeHeader(loans, const ['Direction', 'Person', 'Amount', 'Status']);
    for (final row in data.loans.owedToYou) {
      _appendRow(loans, [_text('Owed to You'), _text(row.partyName), _amount(row.remainingAmount), _text(row.status.displayName)]);
      _styleLastAmountCell(loans, 2);
    }
    for (final row in data.loans.youOwe) {
      _appendRow(loans, [_text('You Owe'), _text(row.partyName), _amount(row.remainingAmount), _text(row.status.displayName)]);
      _styleLastAmountCell(loans, 2);
    }

    _autoFit(summary, 2);
    _autoFit(monthly, 4);
    _autoFit(income, 5);
    _autoFit(expenses, 4);
    _autoFit(categories, 4);
    _autoFit(accounts, 3);
    _autoFit(loans, 4);

    return _finish(excel);
  }

  // ---- shared helpers ----

  Sheet _sheet(Excel excel, String name, {bool isFirst = false}) {
    if (isFirst) {
      final defaultName = excel.getDefaultSheet();
      if (defaultName != null && defaultName != name) {
        excel.rename(defaultName, name);
      }
      return excel[name];
    }
    return excel[name];
  }

  void _writeHeader(Sheet sheet, List<String> headers) {
    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    final rowIndex = sheet.maxRows - 1;
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex)).cellStyle = _headerStyle;
    }
  }

  void _writeRowLabel(Sheet sheet, String label) {
    sheet.appendRow([TextCellValue(label)]);
    final rowIndex = sheet.maxRows - 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = _totalsStyle;
  }

  void _writeCategoryBreakdown(
    Sheet sheet,
    List<CategoryBreakdownRow> rows, {
    bool blankRowAfterHeader = true,
  }) {
    _writeHeader(sheet, const ['Category', 'Transactions', 'Amount', '% of Total']);
    for (final row in rows) {
      _appendRow(sheet, [
        _text(row.categoryName),
        _int(row.transactionCount),
        _amount(row.total),
        _text('${row.percentage.toStringAsFixed(1)}%'),
      ]);
      _styleLastAmountCell(sheet, 2);
    }
  }

  void _appendRow(Sheet sheet, List<CellValue?> values) => sheet.appendRow(values);

  void _appendAmountRow(Sheet sheet, String label, double amount) {
    _appendRow(sheet, [_text(label), _amount(amount)]);
    _styleLastAmountCell(sheet, 1);
  }

  void _appendTotalsRow(
    Sheet sheet,
    String label,
    int amountColumn,
    double amount, {
    List<CellValue?> extra = const [],
  }) {
    final values = <CellValue?>[
      for (var i = 0; i < amountColumn; i++) i == 0 ? _text(label) : _text(''),
      _amount(amount),
      ...extra,
    ];
    sheet.appendRow(values);
    final rowIndex = sheet.maxRows - 1;
    for (var c = 0; c < values.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex)).cellStyle =
          c >= amountColumn ? _amountTotalsStyle : _totalsStyle;
    }
  }

  void _styleLastAmountCell(Sheet sheet, int columnIndex) {
    final rowIndex = sheet.maxRows - 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = _amountStyle;
  }

  void _autoFit(Sheet sheet, int columnCount) {
    for (var c = 0; c < columnCount; c++) {
      sheet.setColumnAutoFit(c);
    }
  }

  Uint8List _finish(Excel excel) {
    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? const []);
  }

  TextCellValue _text(String value) => TextCellValue(value);
  DoubleCellValue _amount(double value) => DoubleCellValue(value);
  IntCellValue _int(int value) => IntCellValue(value);
  DateCellValue _date(DateTime date) => DateCellValue.fromDateTime(date);

  String _monthLabel(DateTime month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  String _accountName(List<AccountModel> accounts, String accountId) {
    for (final account in accounts) {
      if (account.id == accountId) return account.name;
    }
    return 'Unknown';
  }
}
