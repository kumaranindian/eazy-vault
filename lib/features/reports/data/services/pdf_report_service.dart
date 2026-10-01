import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../domain/models/report_models.dart';
import 'pdf_report_kit.dart';

/// Builds the PDF for every report type except "Transaction Statement"
/// (which reuses `TransactionExportService.buildPdf` directly — a flat
/// transaction list is already exactly what that builds). Every method here
/// takes the report's already-computed data (`ReportCalculationService`) and
/// only lays it out; no financial calculation happens in this class.
class PdfReportService {
  const PdfReportService();

  Future<Uint8List> buildMonthlyReport(MonthlyReportData data) async {
    final assets = await PdfReportAssets.load();
    final monthLabel = DateTimeUtils.formatMonthYear(data.month);

    final document = _document(
      assets: assets,
      title: 'Monthly Report',
      period: monthLabel,
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(label: 'Income', value: CurrencyUtils.format(data.income), color: PdfReportAssets.incomeColor),
          SummaryTile(label: 'Expense', value: CurrencyUtils.format(data.expense), color: PdfReportAssets.expenseColor),
          SummaryTile(
            label: 'Net Savings',
            value: CurrencyUtils.formatWithSign(data.netSavings),
            color: data.netSavings >= 0 ? PdfReportAssets.incomeColor : PdfReportAssets.expenseColor,
          ),
          SummaryTile(
            label: 'Total Balance',
            value: CurrencyUtils.format(data.totalBalance),
            color: PdfReportAssets.primaryColor,
          ),
        ]),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Account Balances'),
        data.accounts.isEmpty
            ? PdfReportKit.emptyState('No accounts yet.')
            : PdfReportKit.table(
                headers: const ['Account', 'Type', 'Balance'],
                rows: [
                  for (final account in data.accounts)
                    [account.name, account.type.displayName, CurrencyUtils.format(account.currentBalance)],
                ],
                amountColumnIndex: 2,
              ),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Income by Category'),
        _categoryTable(data.incomeByCategory),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Expense by Category'),
        _categoryTable(data.expenseByCategory),
        if (data.totalOwedToYou > 0 || data.totalYouOwe > 0) ...[
          pw.SizedBox(height: 18),
          PdfReportKit.sectionTitle('Loans & Debts (as of report date)'),
          PdfReportKit.summaryTiles([
            SummaryTile(
              label: 'Owed to You',
              value: CurrencyUtils.format(data.totalOwedToYou),
              color: PdfReportAssets.incomeColor,
            ),
            SummaryTile(
              label: 'You Owe',
              value: CurrencyUtils.format(data.totalYouOwe),
              color: PdfReportAssets.expenseColor,
            ),
            SummaryTile(
              label: 'Net Position',
              value: CurrencyUtils.formatWithSign(data.totalOwedToYou - data.totalYouOwe),
              color: PdfReportAssets.primaryColor,
            ),
          ]),
        ],
        pw.SizedBox(height: 12),
        pw.Text(
          '${data.transactionCount} transaction${data.transactionCount == 1 ? '' : 's'} this month.',
          style: pw.TextStyle(fontSize: 8, color: PdfReportAssets.mutedColor, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
    return document.save();
  }

  Future<Uint8List> buildAccountStatement(AccountStatementData data) async {
    final assets = await PdfReportAssets.load();
    final dateFormat = DateFormat('dd MMM yyyy');
    final period = _periodLabel(data.startDate, data.endDate);

    final document = _document(
      assets: assets,
      title: 'Account Statement',
      period: '${data.account.name} — $period',
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(
            label: 'Opening Balance',
            value: CurrencyUtils.format(data.openingBalance),
            color: PdfReportAssets.mutedColor,
          ),
          SummaryTile(
            label: 'Total Debits',
            value: CurrencyUtils.format(data.totalDebits),
            color: PdfReportAssets.expenseColor,
          ),
          SummaryTile(
            label: 'Total Credits',
            value: CurrencyUtils.format(data.totalCredits),
            color: PdfReportAssets.incomeColor,
          ),
          SummaryTile(
            label: 'Closing Balance',
            value: CurrencyUtils.format(data.closingBalance),
            color: PdfReportAssets.primaryColor,
          ),
        ]),
        pw.SizedBox(height: 18),
        data.lines.isEmpty
            ? PdfReportKit.emptyState('No transactions found for the selected period.')
            : PdfReportKit.table(
                headers: const ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
                columnWidths: const [
                  pw.FlexColumnWidth(1.3),
                  pw.FlexColumnWidth(2.2),
                  pw.FlexColumnWidth(1.2),
                  pw.FlexColumnWidth(1.2),
                  pw.FlexColumnWidth(1.3),
                ],
                rows: [
                  for (final line in data.lines)
                    [
                      dateFormat.format(line.transaction.date),
                      line.description,
                      line.debit > 0 ? CurrencyUtils.format(line.debit) : '',
                      line.credit > 0 ? CurrencyUtils.format(line.credit) : '',
                      CurrencyUtils.format(line.runningBalance),
                    ],
                ],
              ),
      ],
    );
    return document.save();
  }

  Future<Uint8List> buildIncomeReport(IncomeReportData data) async {
    final assets = await PdfReportAssets.load();
    final dateFormat = DateFormat('dd MMM yyyy');
    final monthFormat = DateFormat('MMM yyyy');
    final period = _periodLabel(data.startPeriod, data.endPeriod);

    final document = _document(
      assets: assets,
      title: 'Income Report',
      period: period,
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(label: 'Total Income', value: CurrencyUtils.format(data.total), color: PdfReportAssets.incomeColor),
          SummaryTile(label: 'Records', value: '${data.rows.length}', color: PdfReportAssets.mutedColor),
        ]),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Income by Category'),
        _categoryTable(data.byCategory),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Income Details'),
        data.rows.isEmpty
            ? PdfReportKit.emptyState('No income found for the selected period.')
            : PdfReportKit.table(
                headers: const ['Credited Date', 'Income For', 'Category', 'Account', 'Amount'],
                rows: [
                  for (final row in data.rows)
                    [
                      dateFormat.format(row.creditedDate),
                      monthFormat.format(row.incomeForMonth),
                      row.categoryName,
                      row.accountName,
                      CurrencyUtils.format(row.amount),
                    ],
                ],
                amountColumnIndex: 4,
              ),
      ],
    );
    return document.save();
  }

  Future<Uint8List> buildExpenseReport(ExpenseReportData data) async {
    final assets = await PdfReportAssets.load();
    final dateFormat = DateFormat('dd MMM yyyy');
    final period = _periodLabel(data.startDate, data.endDate);

    final document = _document(
      assets: assets,
      title: 'Expense Report',
      period: period,
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(label: 'Total Expense', value: CurrencyUtils.format(data.total), color: PdfReportAssets.expenseColor),
          SummaryTile(label: 'Records', value: '${data.transactions.length}', color: PdfReportAssets.mutedColor),
        ]),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Category Breakdown'),
        _categoryTable(data.byCategory),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Expense Details'),
        data.transactions.isEmpty
            ? PdfReportKit.emptyState('No expenses found for the selected period.')
            : PdfReportKit.table(
                headers: const ['Date', 'Category', 'Account', 'Description', 'Amount'],
                rows: [
                  for (final t in data.transactions)
                    [
                      dateFormat.format(t.date),
                      data.categoriesById[t.categoryId]?.name ?? t.type.displayName,
                      data.accountsById[t.accountId]?.name ?? 'Unknown',
                      t.description ?? t.vendor ?? '-',
                      CurrencyUtils.format(t.amount),
                    ],
                ],
                amountColumnIndex: 4,
              ),
      ],
    );
    return document.save();
  }

  Future<Uint8List> buildCategoryReport(CategoryReportData data) async {
    final assets = await PdfReportAssets.load();
    final period = _periodLabel(data.startDate, data.endDate);

    final document = _document(
      assets: assets,
      title: 'Category Report',
      period: period,
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(label: 'Total Income', value: CurrencyUtils.format(data.totalIncome), color: PdfReportAssets.incomeColor),
          SummaryTile(
            label: 'Total Expense',
            value: CurrencyUtils.format(data.totalExpense),
            color: PdfReportAssets.expenseColor,
          ),
        ]),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Expense Categories'),
        data.expenseByCategory.isEmpty
            ? PdfReportKit.emptyState('No expenses found for the selected period.')
            : _categoryTable(data.expenseByCategory),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Income Categories'),
        data.incomeByCategory.isEmpty
            ? PdfReportKit.emptyState('No income found for the selected period.')
            : _categoryTable(data.incomeByCategory),
      ],
    );
    return document.save();
  }

  Future<Uint8List> buildLoanDebtReport(LoanDebtReportData data) async {
    final assets = await PdfReportAssets.load();
    final dateFormat = DateFormat('dd MMM yyyy');

    pw.Widget loanTable(List<LoanDebtRow> rows) {
      if (rows.isEmpty) return PdfReportKit.emptyState('Nothing here.');
      return PdfReportKit.table(
        headers: const ['Person', 'Amount', 'Status', 'Due Date'],
        rows: [
          for (final row in rows)
            [
              row.partyName,
              CurrencyUtils.format(row.remainingAmount),
              row.status.displayName,
              row.dueDate == null ? '-' : dateFormat.format(row.dueDate!),
            ],
        ],
        amountColumnIndex: 1,
      );
    }

    final document = _document(
      assets: assets,
      title: 'Loans & Debts Report',
      period: 'As of ${dateFormat.format(DateTime.now())}',
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(
            label: 'Owed to You',
            value: CurrencyUtils.format(data.totalOwedToYou),
            color: PdfReportAssets.incomeColor,
          ),
          SummaryTile(
            label: 'You Owe',
            value: CurrencyUtils.format(data.totalYouOwe),
            color: PdfReportAssets.expenseColor,
          ),
          SummaryTile(
            label: 'Net Position',
            value: CurrencyUtils.formatWithSign(data.netPosition),
            color: data.netPosition >= 0 ? PdfReportAssets.incomeColor : PdfReportAssets.expenseColor,
          ),
        ]),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Owed to You'),
        loanTable(data.owedToYou),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('You Owe'),
        loanTable(data.youOwe),
      ],
    );
    return document.save();
  }

  Future<Uint8List> buildAnnualReport(AnnualReportData data) async {
    final assets = await PdfReportAssets.load();
    final monthFormat = DateFormat('MMMM');

    final document = _document(
      assets: assets,
      title: '${data.year} Financial Report',
      period: 'Full year ${data.year}',
      build: (context) => [
        PdfReportKit.summaryTiles([
          SummaryTile(label: 'Total Income', value: CurrencyUtils.format(data.totalIncome), color: PdfReportAssets.incomeColor),
          SummaryTile(
            label: 'Total Expense',
            value: CurrencyUtils.format(data.totalExpense),
            color: PdfReportAssets.expenseColor,
          ),
          SummaryTile(
            label: 'Net Savings',
            value: CurrencyUtils.formatWithSign(data.netSavings),
            color: data.netSavings >= 0 ? PdfReportAssets.incomeColor : PdfReportAssets.expenseColor,
          ),
          SummaryTile(
            label: 'Total Balance',
            value: CurrencyUtils.format(data.totalBalance),
            color: PdfReportAssets.primaryColor,
          ),
        ]),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Monthly Summary'),
        PdfReportKit.table(
          headers: const ['Month', 'Income', 'Expense', 'Net Savings'],
          rows: [
            for (final m in data.monthly)
              [
                monthFormat.format(m.month),
                CurrencyUtils.format(m.income),
                CurrencyUtils.format(m.expense),
                CurrencyUtils.formatWithSign(m.netSavings),
              ],
          ],
          totalsRow: [
            'Total',
            CurrencyUtils.format(data.totalIncome),
            CurrencyUtils.format(data.totalExpense),
            CurrencyUtils.formatWithSign(data.netSavings),
          ],
        ),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Income by Category'),
        _categoryTable(data.incomeByCategory),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Expense by Category'),
        _categoryTable(data.expenseByCategory),
        pw.SizedBox(height: 18),
        PdfReportKit.sectionTitle('Account Balances'),
        data.accounts.isEmpty
            ? PdfReportKit.emptyState('No accounts yet.')
            : PdfReportKit.table(
                headers: const ['Account', 'Type', 'Balance'],
                rows: [
                  for (final account in data.accounts)
                    [account.name, account.type.displayName, CurrencyUtils.format(account.currentBalance)],
                ],
                amountColumnIndex: 2,
              ),
        if (data.loans.totalOwedToYou > 0 || data.loans.totalYouOwe > 0) ...[
          pw.SizedBox(height: 18),
          PdfReportKit.sectionTitle('Loans & Debts (as of report date)'),
          PdfReportKit.summaryTiles([
            SummaryTile(
              label: 'Owed to You',
              value: CurrencyUtils.format(data.loans.totalOwedToYou),
              color: PdfReportAssets.incomeColor,
            ),
            SummaryTile(
              label: 'You Owe',
              value: CurrencyUtils.format(data.loans.totalYouOwe),
              color: PdfReportAssets.expenseColor,
            ),
          ]),
        ],
      ],
    );
    return document.save();
  }

  // ---- shared helpers ----

  pw.Document _document({
    required PdfReportAssets assets,
    required String title,
    required String period,
    required List<pw.Widget> Function(pw.Context) build,
  }) {
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        theme: assets.theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (context) => context.pageNumber == 1
            ? PdfReportKit.header(assets: assets, title: title, period: period, generatedAt: generatedAt)
            : PdfReportKit.continuationHeader(title),
        footer: (context) => PdfReportKit.footer(assets, context),
        build: build,
      ),
    );
    return document;
  }

  pw.Widget _categoryTable(List<CategoryBreakdownRow> rows) {
    if (rows.isEmpty) return PdfReportKit.emptyState('No transactions found for the selected period.');
    return PdfReportKit.table(
      headers: const ['Category', 'Transactions', 'Amount', '% of Total'],
      rows: [
        for (final row in rows)
          [
            row.categoryName,
            '${row.transactionCount}',
            CurrencyUtils.format(row.total),
            '${row.percentage.toStringAsFixed(0)}%',
          ],
      ],
      amountColumnIndex: 2,
    );
  }

  String _periodLabel(DateTime? start, DateTime? end) {
    final dateFormat = DateFormat('dd MMM yyyy');
    if (start == null && end == null) return 'All time';
    if (start == null) return 'Up to ${dateFormat.format(end!)}';
    if (end == null) return 'From ${dateFormat.format(start)}';
    return '${dateFormat.format(start)} — ${dateFormat.format(end)}';
  }
}
