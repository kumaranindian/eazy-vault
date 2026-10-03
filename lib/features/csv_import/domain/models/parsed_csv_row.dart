enum CsvRowStatus { valid, invalid, duplicate }

/// One data row from the CSV after column mapping has been applied. Rows
/// stay in the list even when [status] is invalid/duplicate so the preview
/// table can show every row with its outcome.
class ParsedCsvRow {
  ParsedCsvRow({
    required this.rowNumber,
    required this.rawValues,
    required this.status,
    this.date,
    this.description,
    this.amount,
    this.category,
    this.issue,
    this.included = true,
  });

  /// 1-based position among the data rows (excluding the header).
  final int rowNumber;
  final List<String> rawValues;

  final DateTime? date;
  final String? description;

  /// Signed: positive is income, negative is expense.
  final double? amount;
  final String? category;

  CsvRowStatus status;
  String? issue;

  /// Whether the user wants this row imported — defaults to true for valid
  /// rows and false for invalid/duplicate ones; the preview lets the user
  /// flip it either way.
  bool included;

  bool get isIncome => (amount ?? 0) > 0;
}
