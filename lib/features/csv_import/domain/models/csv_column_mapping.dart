/// Which CSV column (0-based index into a row) holds each field. Not every
/// bank uses the same layout, so the wizard lets the user map their own
/// file's columns instead of assuming a fixed shape.
class CsvColumnMapping {
  const CsvColumnMapping({
    required this.dateColumn,
    this.descriptionColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.typeColumn,
    this.categoryColumn,
  });

  final int dateColumn;
  final int? descriptionColumn;

  /// A single signed (or unsigned, with [typeColumn] as a sign hint) amount
  /// column. Mutually exclusive with [debitColumn]/[creditColumn] in
  /// practice, but nothing stops both being set — [amountColumn] is ignored
  /// per row once a debit/credit value is present on that row.
  final int? amountColumn;
  final int? debitColumn;
  final int? creditColumn;

  /// Optional "debit"/"credit"/"withdrawal"/"deposit" style column, used to
  /// sign an unsigned [amountColumn] value.
  final int? typeColumn;
  final int? categoryColumn;

  bool get hasAmountSource =>
      amountColumn != null || debitColumn != null || creditColumn != null;
}
