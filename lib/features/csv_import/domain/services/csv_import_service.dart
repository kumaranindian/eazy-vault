import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/logger_service.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/repositories/transactions_repository.dart';
import '../models/csv_column_mapping.dart';
import '../models/import_outcome.dart';
import '../models/parsed_csv_row.dart';

/// Parses an arbitrary bank-statement CSV, applies the user's column
/// mapping, flags duplicates against existing transactions, and imports the
/// result through the normal transaction-creation path (never writes
/// Firestore documents directly) so balances update exactly as they would
/// for a manually entered transaction.
class CsvImportService {
  CsvImportService({required TransactionsRepository transactionsRepository})
      : _transactionsRepository = transactionsRepository;

  final TransactionsRepository _transactionsRepository;

  static const List<String> _dateFormats = [
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'dd-MM-yyyy',
    'dd MMM yyyy',
    'MMM dd, yyyy',
    'dd-MMM-yyyy',
    'yyyy/MM/dd',
  ];

  static const List<String> _debitKeywords = ['debit', 'withdrawal', 'dr', 'expense', 'paid'];
  static const List<String> _creditKeywords = ['credit', 'deposit', 'cr', 'income', 'received'];

  /// Splits raw CSV text into rows of cells. Throws [FormatException] for
  /// content that isn't parseable CSV at all (the caller turns that into a
  /// user-facing "invalid file" message).
  List<List<dynamic>> parseRaw(String content) {
    // Normalize line endings so files from any OS split correctly regardless
    // of which `eol` the converter would otherwise guess.
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(normalized);
    if (rows.isEmpty) {
      throw const FormatException('The file is empty');
    }
    return rows;
  }

  /// Builds one [ParsedCsvRow] per entry in [dataRows] (the header already
  /// stripped by the caller), applying [mapping].
  List<ParsedCsvRow> applyMapping(List<List<dynamic>> dataRows, CsvColumnMapping mapping) {
    final rows = <ParsedCsvRow>[];

    for (var i = 0; i < dataRows.length; i++) {
      final raw = dataRows[i].map((cell) => cell.toString()).toList();
      if (raw.every((cell) => cell.trim().isEmpty)) continue; // blank line

      final rowNumber = i + 1;
      final cell = (int? column) =>
          column == null || column >= raw.length ? '' : raw[column].trim();

      final date = _parseDate(cell(mapping.dateColumn));
      if (date == null) {
        rows.add(ParsedCsvRow(
          rowNumber: rowNumber,
          rawValues: raw,
          status: CsvRowStatus.invalid,
          issue: 'Unrecognized date',
          included: false,
        ));
        continue;
      }

      final amountResult = _parseAmount(
        amountText: cell(mapping.amountColumn),
        debitText: cell(mapping.debitColumn),
        creditText: cell(mapping.creditColumn),
        typeText: cell(mapping.typeColumn),
        hasDebitCreditColumns: mapping.debitColumn != null || mapping.creditColumn != null,
      );

      if (amountResult == null) {
        rows.add(ParsedCsvRow(
          rowNumber: rowNumber,
          rawValues: raw,
          date: date,
          status: CsvRowStatus.invalid,
          issue: 'Missing or unreadable amount',
          included: false,
        ));
        continue;
      }

      rows.add(ParsedCsvRow(
        rowNumber: rowNumber,
        rawValues: raw,
        date: date,
        description: cell(mapping.descriptionColumn).isEmpty ? null : cell(mapping.descriptionColumn),
        amount: amountResult,
        category: cell(mapping.categoryColumn).isEmpty ? null : cell(mapping.categoryColumn),
        status: CsvRowStatus.valid,
      ));
    }

    return rows;
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    for (final pattern in _dateFormats) {
      try {
        return DateFormat(pattern).parseStrict(text);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Returns a signed amount (positive = income, negative = expense), or
  /// `null` if no usable amount could be determined.
  double? _parseAmount({
    required String amountText,
    required String debitText,
    required String creditText,
    required String typeText,
    required bool hasDebitCreditColumns,
  }) {
    if (hasDebitCreditColumns) {
      final debit = _cleanNumber(debitText);
      final credit = _cleanNumber(creditText);
      final hasDebit = debit != null && debit != 0;
      final hasCredit = credit != null && credit != 0;
      if (hasDebit && hasCredit) return null; // ambiguous row
      if (hasDebit) return -debit!.abs();
      if (hasCredit) return credit!.abs();
      return null;
    }

    final amount = _cleanNumber(amountText);
    if (amount == null) return null;

    if (amount == 0) return null;

    // A mapped type column, when present, overrides the amount's own sign —
    // some banks export an always-positive amount plus a separate
    // debit/credit indicator.
    final type = typeText.toLowerCase();
    if (type.isNotEmpty) {
      if (_debitKeywords.any(type.contains)) return -amount.abs();
      if (_creditKeywords.any(type.contains)) return amount.abs();
    }

    // Otherwise trust the amount's own sign (the "signed amount" shape).
    return amount;
  }

  /// Strips currency symbols and thousands separators (`₹1,23,456.78` ->
  /// `1234 56.78`-safe digits) before parsing.
  double? _cleanNumber(String text) {
    if (text.trim().isEmpty) return null;
    final cleaned = text.replaceAll(RegExp(r'[^\d.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-') return null;
    return double.tryParse(cleaned);
  }

  /// Marks rows as duplicates of an existing transaction on the same
  /// account with the same date, amount and description. Mutates and
  /// returns [rows].
  Future<List<ParsedCsvRow>> markDuplicates(
    String userId,
    String accountId,
    List<ParsedCsvRow> rows,
  ) async {
    final validRows = rows.where((r) => r.status == CsvRowStatus.valid).toList();
    if (validRows.isEmpty) return rows;

    final dates = validRows.map((r) => r.date!).toList()..sort();
    final earliest = dates.first;
    final latest = dates.last;
    final result = await _transactionsRepository.getTransactions(
      userId,
      accountId: accountId,
      startDate: DateTime(earliest.year, earliest.month, earliest.day),
      endDate: DateTime(latest.year, latest.month, latest.day, 23, 59, 59, 999),
      limit: 1000,
    );
    if (result.failure != null) {
      LoggerService.error('Failed to load existing transactions for duplicate check');
      return rows;
    }

    final existingSignatures = {
      for (final transaction in result.transactions)
        if (transaction.type == TransactionType.income || transaction.type == TransactionType.expense)
          _signature(
            date: transaction.date,
            amount: transaction.amount * (transaction.type == TransactionType.expense ? -1 : 1),
            description: transaction.description,
          ),
    };

    for (final row in rows) {
      if (row.status != CsvRowStatus.valid) continue;
      final signature = _signature(date: row.date!, amount: row.amount!, description: row.description);
      if (existingSignatures.contains(signature)) {
        row.status = CsvRowStatus.duplicate;
        row.issue = 'Matches an existing transaction';
        row.included = false;
      }
    }

    return rows;
  }

  String _signature({required DateTime date, required double amount, String? description}) {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final descriptionKey = (description ?? '').trim().toLowerCase();
    return '$dateKey|${amount.abs().toStringAsFixed(2)}|$descriptionKey';
  }

  /// Creates a transaction per included row via the normal transaction path
  /// (`TransactionsRepository.createTransaction`, backed by
  /// `AccountBalanceService`) — never a direct Firestore write.
  Future<ImportOutcome> import(
    String userId, {
    required String accountId,
    required String incomeCategoryId,
    required String expenseCategoryId,
    required Map<String, String> categoryIdsByName,
    required List<ParsedCsvRow> rows,
    void Function(int completed, int total)? onProgress,
  }) async {
    var imported = 0;
    var failed = 0;
    final invalid = rows.where((r) => r.status == CsvRowStatus.invalid).length;
    final skippedDuplicates = rows.where((r) => r.status == CsvRowStatus.duplicate).length;

    final toImport = rows.where((r) => r.included && r.status == CsvRowStatus.valid).toList();
    final now = DateTime.now();
    var completed = 0;
    for (final row in toImport) {

      final isIncome = row.isIncome;
      final matchedCategoryId = row.category == null
          ? null
          : categoryIdsByName[row.category!.trim().toLowerCase()];

      final transaction = TransactionModel(
        id: '',
        type: isIncome ? TransactionType.income : TransactionType.expense,
        amount: row.amount!.abs(),
        accountId: accountId,
        categoryId: matchedCategoryId ?? (isIncome ? incomeCategoryId : expenseCategoryId),
        date: row.date!,
        description: row.description,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
      );

      final result = await _transactionsRepository.createTransaction(userId, transaction);
      if (result.failure != null) {
        failed++;
      } else {
        imported++;
      }
      completed++;
      onProgress?.call(completed, toImport.length);
    }

    return ImportOutcome(
      imported: imported,
      skippedDuplicates: skippedDuplicates,
      invalid: invalid,
      failed: failed,
    );
  }
}
