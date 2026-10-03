import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../domain/models/csv_column_mapping.dart';
import '../../domain/models/import_outcome.dart';
import '../../domain/models/parsed_csv_row.dart';
import '../../domain/services/csv_import_service.dart';
import '../providers/csv_import_providers.dart';

enum _Step { selectFile, mapColumns, preview, importing, done }

class CsvImportPage extends ConsumerStatefulWidget {
  const CsvImportPage({super.key});

  @override
  ConsumerState<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends ConsumerState<CsvImportPage> {
  _Step _step = _Step.selectFile;
  bool _isBusy = false;
  String? _error;

  List<List<dynamic>>? _rawRows;
  List<String> _headers = [];

  int? _dateCol;
  int? _descriptionCol;
  int? _amountCol;
  int? _debitCol;
  int? _creditCol;
  int? _typeCol;
  int? _categoryCol;
  bool _useDebitCredit = false;

  String? _accountId;
  String? _incomeCategoryId;
  String? _expenseCategoryId;

  List<ParsedCsvRow> _previewRows = [];
  int _importProgressDone = 0;
  int _importProgressTotal = 0;
  ImportOutcome? _outcome;

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _isBusy = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isBusy = false);
        return;
      }

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        setState(() {
          _isBusy = false;
          _error = "Couldn't read the selected file. Please try again.";
        });
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final service = ref.read(csvImportServiceProvider);
      final rows = service.parseRaw(content);

      if (!mounted) return;
      setState(() {
        _rawRows = rows;
        _headers = rows.first.map((cell) => cell.toString()).toList();
        _dateCol = _guessColumn(_headers, ['date']);
        _descriptionCol = _guessColumn(_headers, ['description', 'narration', 'details']);
        _amountCol = _guessColumn(_headers, ['amount']);
        _debitCol = _guessColumn(_headers, ['debit', 'withdrawal']);
        _creditCol = _guessColumn(_headers, ['credit', 'deposit']);
        _useDebitCredit = _debitCol != null && _creditCol != null;
        _typeCol = _guessColumn(_headers, ['type']);
        _categoryCol = _guessColumn(_headers, ['category']);
        _isBusy = false;
        _step = _Step.mapColumns;
      });
    } on FormatException catch (e) {
      setState(() {
        _isBusy = false;
        _error = 'Import failed. ${e.message}';
      });
    } catch (_) {
      setState(() {
        _isBusy = false;
        _error = 'Import failed. Please check the file and try again.';
      });
    }
  }

  int? _guessColumn(List<String> headers, List<String> keywords) {
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      if (keywords.any(header.contains)) return i;
    }
    return null;
  }

  Future<void> _buildPreview() async {
    if (_dateCol == null) {
      context.showErrorSnackBar('Please map the Date column');
      return;
    }
    final hasAmountSource =
        _useDebitCredit ? (_debitCol != null || _creditCol != null) : _amountCol != null;
    if (!hasAmountSource) {
      context.showErrorSnackBar('Please map an amount column');
      return;
    }
    if (_accountId == null) {
      context.showErrorSnackBar('Please select an account to import into');
      return;
    }
    if (_incomeCategoryId == null || _expenseCategoryId == null) {
      context.showErrorSnackBar('Please select default categories');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showErrorSnackBar('Your session has expired. Please sign in again.');
      return;
    }

    setState(() => _isBusy = true);

    final mapping = CsvColumnMapping(
      dateColumn: _dateCol!,
      descriptionColumn: _descriptionCol,
      amountColumn: _useDebitCredit ? null : _amountCol,
      debitColumn: _useDebitCredit ? _debitCol : null,
      creditColumn: _useDebitCredit ? _creditCol : null,
      typeColumn: _typeCol,
      categoryColumn: _categoryCol,
    );

    final service = ref.read(csvImportServiceProvider);
    final dataRows = _rawRows!.sublist(1);
    var rows = service.applyMapping(dataRows, mapping);
    rows = await service.markDuplicates(user.uid, _accountId!, rows);

    if (!mounted) return;
    setState(() {
      _previewRows = rows;
      _isBusy = false;
      _step = _Step.preview;
    });
  }

  Future<void> _confirmImport() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final categoriesState = ref.read(categoriesNotifierProvider);
    final categoryIdsByName = categoriesState.maybeWhen<Map<String, String>>(
      loaded: (categories) => {
        for (final category in categories) category.name.trim().toLowerCase(): category.id,
      },
      orElse: () => const {},
    );

    setState(() {
      _step = _Step.importing;
      _importProgressDone = 0;
      _importProgressTotal = _previewRows.where((r) => r.included && r.status == CsvRowStatus.valid).length;
    });

    final service = ref.read(csvImportServiceProvider);
    final outcome = await service.import(
      user.uid,
      accountId: _accountId!,
      incomeCategoryId: _incomeCategoryId!,
      expenseCategoryId: _expenseCategoryId!,
      categoryIdsByName: categoryIdsByName,
      rows: _previewRows,
      onProgress: (completed, total) {
        if (!mounted) return;
        setState(() {
          _importProgressDone = completed;
          _importProgressTotal = total;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      _step = _Step.done;
    });
  }

  void _reset() {
    setState(() {
      _step = _Step.selectFile;
      _rawRows = null;
      _headers = [];
      _previewRows = [];
      _outcome = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Transactions')),
      body: ResponsiveContent(
        maxWidth: 800,
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: switch (_step) {
            _Step.selectFile => _buildSelectFile(context),
            _Step.mapColumns => _buildMapColumns(context),
            _Step.preview => _buildPreviewStep(context),
            _Step.importing => _buildImporting(context),
            _Step.done => _buildDone(context),
          },
        ),
      ),
    );
  }

  Widget _buildSelectFile(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file_outlined, size: 64, color: context.colorScheme.primary),
          AppSpacing.gapMD,
          Text(
            'Import a bank statement CSV',
            style: context.textTheme.titleMedium,
          ),
          AppSpacing.gapSM,
          Text(
            "We'll walk you through mapping your file's columns before anything is imported.",
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapXL,
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: context.colorScheme.error)),
            AppSpacing.gapMD,
          ],
          ElevatedButton.icon(
            onPressed: _isBusy ? null : _pickFile,
            icon: _isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_outlined),
            label: Text(_isBusy ? 'Analyzing CSV...' : 'Select CSV File'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapColumns(BuildContext context) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final accounts = accountsState.maybeWhen<List<AccountModel>>(
      loaded: (accounts) => accounts.where((a) => a.isActive).toList(),
      orElse: () => <AccountModel>[],
    );
    final categoriesState = ref.watch(categoriesNotifierProvider);
    final incomeCategories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (categories) =>
          categories.where((c) => c.type == CategoryType.income && c.isActive).toList(),
      orElse: () => <CategoryModel>[],
    );
    final expenseCategories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (categories) =>
          categories.where((c) => c.type == CategoryType.expense && c.isActive).toList(),
      orElse: () => <CategoryModel>[],
    );

    return ListView(
      children: [
        Text('Map your columns', style: context.textTheme.titleMedium),
        AppSpacing.gapSM,
        Text(
          'Match the fields in your CSV to EazyVault. Row 1 is treated as the header.',
          style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
        AppSpacing.gapLG,
        _columnDropdown('Date (required)', _dateCol, (v) => setState(() => _dateCol = v)),
        AppSpacing.gapMD,
        _columnDropdown('Description', _descriptionCol, (v) => setState(() => _descriptionCol = v)),
        AppSpacing.gapMD,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Separate debit/credit columns'),
          subtitle: const Text('Off: a single signed amount column'),
          value: _useDebitCredit,
          onChanged: (v) => setState(() => _useDebitCredit = v),
        ),
        if (_useDebitCredit) ...[
          _columnDropdown('Debit', _debitCol, (v) => setState(() => _debitCol = v)),
          AppSpacing.gapMD,
          _columnDropdown('Credit', _creditCol, (v) => setState(() => _creditCol = v)),
        ] else
          _columnDropdown('Amount (required)', _amountCol, (v) => setState(() => _amountCol = v)),
        AppSpacing.gapMD,
        _columnDropdown(
          'Type (debit/credit hint, optional)',
          _typeCol,
          (v) => setState(() => _typeCol = v),
        ),
        AppSpacing.gapMD,
        _columnDropdown('Category (optional)', _categoryCol, (v) => setState(() => _categoryCol = v)),
        AppSpacing.gapXL,
        const Divider(),
        AppSpacing.gapMD,
        Text('Import into', style: context.textTheme.titleMedium),
        AppSpacing.gapMD,
        DropdownButtonFormField<String>(
          value: _accountId,
          decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
          items: accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (v) => setState(() => _accountId = v),
        ),
        AppSpacing.gapMD,
        DropdownButtonFormField<String>(
          value: _incomeCategoryId,
          decoration: const InputDecoration(labelText: 'Default income category', prefixIcon: Icon(Icons.arrow_upward)),
          items: incomeCategories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: (v) => setState(() => _incomeCategoryId = v),
        ),
        AppSpacing.gapMD,
        DropdownButtonFormField<String>(
          value: _expenseCategoryId,
          decoration: const InputDecoration(labelText: 'Default expense category', prefixIcon: Icon(Icons.arrow_downward)),
          items: expenseCategories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: (v) => setState(() => _expenseCategoryId = v),
        ),
        AppSpacing.gapXL,
        ElevatedButton.icon(
          onPressed: _isBusy ? null : _buildPreview,
          icon: _isBusy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.preview_outlined),
          label: Text(_isBusy ? 'Analyzing CSV...' : 'Preview'),
        ),
      ],
    );
  }

  Widget _columnDropdown(String label, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Not mapped')),
        for (var i = 0; i < _headers.length; i++)
          DropdownMenuItem(value: i, child: Text(_headers[i])),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildPreviewStep(BuildContext context) {
    final total = _previewRows.length;
    final valid = _previewRows.where((r) => r.status == CsvRowStatus.valid).length;
    final invalid = _previewRows.where((r) => r.status == CsvRowStatus.invalid).length;
    final duplicate = _previewRows.where((r) => r.status == CsvRowStatus.duplicate).length;
    final readyToImport = _previewRows.where((r) => r.included).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _statChip('Total', total, null),
            _statChip('Valid', valid, Colors.green),
            _statChip('Duplicate', duplicate, Colors.orange),
            _statChip('Invalid', invalid, Colors.red),
            _statChip('Ready to import', readyToImport, context.colorScheme.primary),
          ],
        ),
        AppSpacing.gapMD,
        Expanded(
          child: ListView.separated(
            itemCount: _previewRows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = _previewRows[index];
              return CheckboxListTile(
                value: row.included,
                onChanged: row.status == CsvRowStatus.invalid
                    ? null
                    : (v) => setState(() => row.included = v ?? false),
                title: Text(
                  row.description?.isNotEmpty == true ? row.description! : 'Row ${row.rowNumber}',
                ),
                subtitle: Text(
                  row.status == CsvRowStatus.invalid
                      ? row.issue ?? 'Invalid row'
                      : row.status == CsvRowStatus.duplicate
                          ? row.issue ?? 'Possible duplicate'
                          : '${row.date != null ? row.date!.toIso8601String().split('T').first : ''} '
                              '• ${row.amount! > 0 ? 'Income' : 'Expense'}',
                  style: TextStyle(
                    color: row.status == CsvRowStatus.invalid
                        ? Colors.red
                        : row.status == CsvRowStatus.duplicate
                            ? Colors.orange
                            : null,
                  ),
                ),
                secondary: row.amount == null
                    ? null
                    : Text(
                        row.amount!.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: row.amount! > 0 ? Colors.green : Colors.red,
                        ),
                      ),
              );
            },
          ),
        ),
        AppSpacing.gapMD,
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _step = _Step.mapColumns),
              child: const Text('Back'),
            ),
            AppSpacing.gapMD,
            Expanded(
              child: ElevatedButton(
                onPressed: readyToImport == 0 ? null : _confirmImport,
                child: Text('Import $readyToImport Transaction${readyToImport == 1 ? '' : 's'}'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statChip(String label, int value, Color? color) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color?.withOpacity(0.1),
      labelStyle: color == null ? null : TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildImporting(BuildContext context) {
    final progress = _importProgressTotal == 0 ? null : _importProgressDone / _importProgressTotal;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(value: progress),
          ),
          AppSpacing.gapMD,
          Text(
            _importProgressTotal == 0
                ? 'Importing transactions...'
                : 'Importing $_importProgressDone of $_importProgressTotal transactions',
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final outcome = _outcome;
    if (outcome == null) return const LoadingIndicator();

    final summary = 'Import completed. ${outcome.imported} transaction'
        '${outcome.imported == 1 ? '' : 's'} imported'
        '${outcome.skippedDuplicates > 0 ? ', ${outcome.skippedDuplicates} skipped as duplicates' : ''}'
        '${outcome.invalid > 0 ? ', ${outcome.invalid} invalid' : ''}'
        '${outcome.failed > 0 ? ', ${outcome.failed} failed' : ''}.';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            outcome.isFullSuccess ? Icons.check_circle_outline : Icons.info_outline,
            size: 64,
            color: outcome.isFullSuccess ? Colors.green : Colors.orange,
          ),
          AppSpacing.gapMD,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(summary, textAlign: TextAlign.center),
          ),
          AppSpacing.gapXL,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: _reset, child: const Text('Import Another File')),
              AppSpacing.gapMD,
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
