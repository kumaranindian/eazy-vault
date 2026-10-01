import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';

/// One label/value/color tile in a report's summary row (e.g. "Total Income
/// ₹50,000" in green).
class SummaryTile {
  const SummaryTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final PdfColor color;
}

/// Fonts, logos and colors every report PDF shares, loaded once per
/// generation so each report method doesn't re-read assets/fonts.
class PdfReportAssets {
  const PdfReportAssets({
    required this.logoImage,
    required this.companyLogoImage,
    required this.regularFont,
    required this.boldFont,
    required this.italicFont,
  });

  final pw.MemoryImage logoImage;
  final pw.MemoryImage companyLogoImage;
  final pw.Font regularFont;
  final pw.Font boldFont;
  final pw.Font italicFont;

  static final primaryColor = PdfColor.fromInt(AppColors.primary.value);
  static final incomeColor = PdfColor.fromInt(AppColors.income.value);
  static final expenseColor = PdfColor.fromInt(AppColors.expense.value);
  static final mutedColor = PdfColor.fromInt(AppColors.textSecondary.value);
  static final borderColor = PdfColor.fromInt(AppColors.border.value);

  static Future<PdfReportAssets> load() async {
    final logoBytes = (await rootBundle.load('eazyvault_logo.png')).buffer.asUint8List();
    final companyLogoBytes = (await rootBundle.load('avail404.png')).buffer.asUint8List();
    // The base14 PDF fonts don't cover the ₹ glyph; Noto Sans does.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    return PdfReportAssets(
      logoImage: pw.MemoryImage(logoBytes),
      companyLogoImage: pw.MemoryImage(companyLogoBytes),
      regularFont: regularFont,
      boldFont: boldFont,
      italicFont: italicFont,
    );
  }

  pw.ThemeData get theme =>
      pw.ThemeData.withFont(base: regularFont, bold: boldFont, italic: italicFont);
}

/// Shared building blocks for every report PDF: branding header, summary
/// tiles, a paginated table and a branded footer with page numbers. Reused
/// across all report types so each one only needs to supply its own data —
/// see `PdfReportService`. `TransactionExportService.buildPdf` predates this
/// kit and keeps its own equivalent code (a flat transaction list is simple
/// enough on its own); the "Transaction Statement" report type calls it
/// directly instead of duplicating it here.
class PdfReportKit {
  const PdfReportKit._();

  static pw.Widget header({
    required PdfReportAssets assets,
    required String title,
    required String period,
    required String generatedAt,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(assets.logoImage, width: 40, height: 40),
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
                      color: PdfReportAssets.primaryColor,
                    ),
                  ),
                  pw.Text(
                    AppConfig.appTagline,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfReportAssets.mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(period, style: pw.TextStyle(fontSize: 9, color: PdfReportAssets.mutedColor)),
                pw.Text(
                  'Generated: $generatedAt',
                  style: pw.TextStyle(fontSize: 8, color: PdfReportAssets.mutedColor),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: PdfReportAssets.primaryColor),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget continuationHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfReportAssets.borderColor)),
      ),
      child: pw.Text(
        '${AppConfig.appName} — $title',
        style: pw.TextStyle(fontSize: 9, color: PdfReportAssets.mutedColor),
      ),
    );
  }

  static pw.Widget footer(PdfReportAssets assets, pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfReportAssets.borderColor)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(assets.companyLogoImage, width: 14, height: 14),
              pw.SizedBox(width: 6),
              pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfReportAssets.mutedColor,
                  ),
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
            style: pw.TextStyle(fontSize: 8, color: PdfReportAssets.mutedColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget summaryTiles(List<SummaryTile> tiles) {
    return pw.Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 12),
          pw.Expanded(child: _summaryTile(tiles[i])),
        ],
      ],
    );
  }

  static pw.Widget _summaryTile(SummaryTile tile) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF5F5F5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(tile.label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(
            tile.value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tile.color),
          ),
        ],
      ),
    );
  }

  static pw.Widget sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfReportAssets.primaryColor),
      ),
    );
  }

  /// A paginated table: bold header row on a brand-colored background,
  /// striped body rows, and an optional bold totals row. [amountColumnIndex]
  /// (if set) colors that column's text per row using [amountColumnColors]
  /// (defaults to black when omitted/shorter than [rows]).
  static pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    List<pw.TableColumnWidth>? columnWidths,
    int? amountColumnIndex,
    List<PdfColor>? amountColumnColors,
    List<String>? totalsRow,
  }) {
    return pw.Table(
      columnWidths: columnWidths == null
          ? null
          : {for (var i = 0; i < columnWidths.length; i++) i: columnWidths[i]},
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfReportAssets.borderColor, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfReportAssets.primaryColor),
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
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfColor.fromInt(0xFFFAFAFA),
            ),
            children: [
              for (var c = 0; c < rows[i].length; c++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(
                    rows[i][c],
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: c == amountColumnIndex
                          ? (amountColumnColors != null && i < amountColumnColors.length
                              ? amountColumnColors[i]
                              : PdfColors.black)
                          : PdfColors.black,
                      fontWeight: c == amountColumnIndex ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        if (totalsRow != null)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0F0)),
            children: totalsRow
                .map((value) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: pw.Text(
                        value,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }

  static pw.Widget emptyState(String message) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 24),
      child: pw.Center(
        child: pw.Text(
          message,
          style: pw.TextStyle(fontSize: 11, color: PdfReportAssets.mutedColor, fontStyle: pw.FontStyle.italic),
        ),
      ),
    );
  }
}
