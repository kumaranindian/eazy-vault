import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../categories/data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../extensions/transaction_extensions.dart';

/// Builds CSV and branded PDF exports of a transaction list. Pure data/byte
/// generation only — triggering the browser download is a separate, UI-layer
/// concern (see `core/utils/web_download.dart`).
class TransactionExportService {
  const TransactionExportService();

  /// RFC 4180-ish CSV: one header row, one row per transaction. Starts with
  /// a UTF-8 BOM so Excel renders non-ASCII text (names with accents, etc.)
  /// correctly instead of mangling it.
  String buildCsv(
    List<TransactionModel> transactions, {
    required Map<String, AccountModel> accountsById,
    required Map<String, CategoryModel> categoriesById,
  }) {
    final buffer = StringBuffer('﻿');
    final dateFormat = DateFormat('yyyy-MM-dd');

    buffer.writeln(_csvRow([
      'Date',
      'Type',
      'Category',
      'Account',
      'Description',
      'Vendor',
      'Amount',
      'Income For',
    ]));

    for (final transaction in transactions) {
      buffer.writeln(_csvRow([
        dateFormat.format(transaction.date),
        transaction.type.displayName,
        categoriesById[transaction.categoryId]?.name ?? transaction.type.displayName,
        accountsById[transaction.accountId]?.name ?? 'Unknown',
        transaction.description ?? '',
        transaction.vendor ?? '',
        transaction.amount.toStringAsFixed(2),
        transaction.type == TransactionType.income
            ? DateFormat('yyyy-MM').format(transaction.incomeReportingMonth)
            : '',
      ]));
    }

    return buffer.toString();
  }

  String _csvRow(List<String> fields) => fields.map(_csvEscape).join(',');

  String _csvEscape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// A branded PDF report: logo + app header, a summary strip, then a
  /// transaction table. [filterDescription] is shown under the title (e.g.
  /// "Expense — This Month").
  Future<Uint8List> buildPdf(
    List<TransactionModel> transactions, {
    required Map<String, AccountModel> accountsById,
    required Map<String, CategoryModel> categoriesById,
    required String filterDescription,
  }) async {
    final document = pw.Document();

    final logoBytes = (await rootBundle.load('eazyvault_logo.png')).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    // AVAIL404 is the company behind EazyVault (see the "Powered By"
    // footer elsewhere in the app); its own mark goes in the report footer,
    // separate from the EazyVault product logo in the header.
    final companyLogoBytes = (await rootBundle.load('avail404.png')).buffer.asUint8List();
    final companyLogoImage = pw.MemoryImage(companyLogoBytes);

    // The base14 PDF fonts don't cover the ₹ glyph; Noto Sans does.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    final primaryColor = PdfColor.fromInt(AppColors.primary.value);
    final incomeColor = PdfColor.fromInt(AppColors.income.value);
    final expenseColor = PdfColor.fromInt(AppColors.expense.value);
    final mutedColor = PdfColor.fromInt(AppColors.textSecondary.value);
    final borderColor = PdfColor.fromInt(AppColors.border.value);

    final dateFormat = DateFormat('dd MMM yyyy');
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    double totalIncome = 0;
    double totalExpense = 0;
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        totalExpense += transaction.amount;
      }
    }

    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont, italic: italicFont),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: borderColor)),
              ),
              child: pw.Text(
                '${AppConfig.appName} — Transaction Report',
                style: pw.TextStyle(fontSize: 9, color: mutedColor),
              ),
            );
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logoImage, width: 40, height: 40),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          AppConfig.appName,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text(
                          AppConfig.appTagline,
                          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Transaction Report',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        filterDescription,
                        style: pw.TextStyle(fontSize: 9, color: mutedColor),
                      ),
                      pw.Text(
                        'Generated: $generatedAt',
                        style: pw.TextStyle(fontSize: 8, color: mutedColor),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderColor)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(companyLogoImage, width: 14, height: 14),
                  pw.SizedBox(width: 6),
                  pw.RichText(
                    text: pw.TextSpan(
                      style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: mutedColor),
                      children: [
                        const pw.TextSpan(text: 'Powered By '),
                        pw.TextSpan(
                          text: 'AVAIL404 Private Limited',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: mutedColor),
              ),
            ],
          ),
        ),
        build: (context) => [
          _buildSummary(totalIncome, totalExpense, transactions.length, mutedColor, incomeColor, expenseColor),
          pw.SizedBox(height: 16),
          _buildTable(
            transactions,
            accountsById: accountsById,
            categoriesById: categoriesById,
            dateFormat: dateFormat,
            primaryColor: primaryColor,
            incomeColor: incomeColor,
            expenseColor: expenseColor,
            borderColor: borderColor,
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildSummary(
    double totalIncome,
    double totalExpense,
    int count,
    PdfColor mutedColor,
    PdfColor incomeColor,
    PdfColor expenseColor,
  ) {
    return pw.Row(
      children: [
        _summaryTile('Total Income', CurrencyUtils.format(totalIncome), incomeColor),
        pw.SizedBox(width: 12),
        _summaryTile('Total Expense', CurrencyUtils.format(totalExpense), expenseColor),
        pw.SizedBox(width: 12),
        _summaryTile(
          'Net',
          CurrencyUtils.formatWithSign(totalIncome - totalExpense),
          totalIncome - totalExpense >= 0 ? incomeColor : expenseColor,
        ),
        pw.SizedBox(width: 12),
        _summaryTile('Transactions', '$count', mutedColor),
      ],
    );
  }

  pw.Widget _summaryTile(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF5F5F5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTable(
    List<TransactionModel> transactions, {
    required Map<String, AccountModel> accountsById,
    required Map<String, CategoryModel> categoriesById,
    required DateFormat dateFormat,
    required PdfColor primaryColor,
    required PdfColor incomeColor,
    required PdfColor expenseColor,
    required PdfColor borderColor,
  }) {
    const headers = ['Date', 'Type', 'Category', 'Account', 'Description', 'Amount', 'Income For'];
    final columnWidths = {
      0: const pw.FlexColumnWidth(1.4),
      1: const pw.FlexColumnWidth(1.2),
      2: const pw.FlexColumnWidth(1.6),
      3: const pw.FlexColumnWidth(1.6),
      4: const pw.FlexColumnWidth(2.4),
      5: const pw.FlexColumnWidth(1.4),
      6: const pw.FlexColumnWidth(1.2),
    };

    return pw.Table(
      columnWidths: columnWidths,
      border: pw.TableBorder(horizontalInside: pw.BorderSide(color: borderColor, width: 0.5)),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primaryColor),
          children: headers
              .map((header) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ))
              .toList(),
        ),
        for (int i = 0; i < transactions.length; i++)
          _buildRow(
            transactions[i],
            accountsById: accountsById,
            categoriesById: categoriesById,
            dateFormat: dateFormat,
            incomeColor: incomeColor,
            expenseColor: expenseColor,
            isEven: i.isEven,
          ),
      ],
    );
  }

  pw.TableRow _buildRow(
    TransactionModel transaction, {
    required Map<String, AccountModel> accountsById,
    required Map<String, CategoryModel> categoriesById,
    required DateFormat dateFormat,
    required PdfColor incomeColor,
    required PdfColor expenseColor,
    required bool isEven,
  }) {
    final isIncome = transaction.type == TransactionType.income ||
        transaction.type == TransactionType.loanTaken;
    final amountColor = transaction.type == TransactionType.transfer ||
            transaction.type == TransactionType.loanRepayment
        ? PdfColors.black
        : (isIncome ? incomeColor : expenseColor);
    final amountPrefix = transaction.type == TransactionType.transfer ||
            transaction.type == TransactionType.loanRepayment
        ? ''
        : (isIncome ? '+' : '-');

    final categoryName = categoriesById[transaction.categoryId]?.name ?? transaction.type.displayName;
    final accountName = accountsById[transaction.accountId]?.name ?? 'Unknown';

    const amountColumnIndex = 5;
    final cells = [
      dateFormat.format(transaction.date),
      transaction.type.displayName,
      categoryName,
      accountName,
      transaction.description ?? transaction.vendor ?? '-',
      '$amountPrefix${CurrencyUtils.format(transaction.amount)}',
      transaction.type == TransactionType.income
          ? DateFormat('MMM yyyy').format(transaction.incomeReportingMonth)
          : '-',
    ];

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isEven ? PdfColors.white : PdfColor.fromInt(0xFFFAFAFA),
      ),
      children: [
        for (int i = 0; i < cells.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(
              cells[i],
              style: pw.TextStyle(
                fontSize: 8.5,
                color: i == amountColumnIndex ? amountColor : PdfColors.black,
                fontWeight: i == amountColumnIndex ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
}
