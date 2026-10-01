import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/web_download.dart';
import '../../../../core/widgets/branded_dialog_title.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/month_year_picker.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../data/services/excel_report_service.dart';
import '../../data/services/pdf_report_service.dart';
import '../../domain/enums/report_type.dart';
import '../../domain/services/report_calculation_service.dart';
import '../providers/reports_providers.dart';

typedef _PreviewSummary = ({int records, double income, double expense});

/// A reusable filter/preview/export dialog, parameterized by [ReportType],
/// used by the Reports hub and by every contextual "Export" action. One
/// widget serves all 8 report types instead of a bespoke screen per type.
class ExportConfigSheet extends ConsumerStatefulWidget {
  const ExportConfigSheet({
    super.key,
    required this.reportType,
    this.initialAccountId,
    this.initialMonth,
    this.initialStartDate,
    this.initialEndDate,
    this.initialType,
    this.initialCategoryId,
  });

  final ReportType reportType;
  final String? initialAccountId;
  final DateTime? initialMonth;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final TransactionType? initialType;
  final String? initialCategoryId;

  static Future<void> show(
    BuildContext context, {
    required ReportType reportType,
    String? initialAccountId,
    DateTime? initialMonth,
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    TransactionType? initialType,
    String? initialCategoryId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ExportConfigSheet(
        reportType: reportType,
        initialAccountId: initialAccountId,
        initialMonth: initialMonth,
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        initialType: initialType,
        initialCategoryId: initialCategoryId,
      ),
    );
  }

  @override
  ConsumerState<ExportConfigSheet> createState() => _ExportConfigSheetState();
}

class _ExportConfigSheetState extends ConsumerState<ExportConfigSheet> {
  late DateTime _month = widget.initialMonth ?? DateTime(DateTime.now().year, DateTime.now().month);
  late int _year = DateTime.now().year;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _accountId;
  String? _categoryId;
  TransactionType? _type;

  _PreviewSummary? _preview;
  bool _isLoadingPreview = false;
  bool _isExporting = false;
  String? _error;

  ReportType get _reportType => widget.reportType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate ?? (widget.reportType.usesDateRange ? _defaultStartDate() : null);
    _endDate = widget.initialEndDate ?? (widget.reportType.usesDateRange ? DateTime.now() : null);
    _accountId = widget.initialAccountId;
    _categoryId = widget.initialCategoryId;
    _type = widget.initialType;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
  }

  DateTime _defaultStartDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> _refreshPreview() async {
    if (_reportType.requiresAccount && _accountId == null) {
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoadingPreview = true;
      _error = null;
    });

    try {
      final service = ref.read(reportCalculationServiceProvider);
      final summary = await _computePreview(service, user.uid);
      if (!mounted) return;
      setState(() {
        _preview = summary;
        _isLoadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.from(e, action: 'load the preview');
        _isLoadingPreview = false;
      });
    }
  }

  Future<_PreviewSummary> _computePreview(ReportCalculationService service, String userId) async {
    switch (_reportType) {
      case ReportType.monthly:
        final data = await service.monthlyReport(userId, _month);
        return (records: data.transactionCount, income: data.income, expense: data.expense);
      case ReportType.transactionStatement:
        final data = await service.transactionReport(
          userId,
          type: _type,
          accountId: _accountId,
          categoryId: _categoryId,
          startDate: _startDate,
          endDate: _endDate,
        );
        return (records: data.transactions.length, income: data.totalIncome, expense: data.totalExpense);
      case ReportType.accountStatement:
        final data = await service.accountStatement(
          userId,
          _accountId!,
          startDate: _startDate,
          endDate: _endDate,
        );
        return (records: data.lines.length, income: data.totalCredits, expense: data.totalDebits);
      case ReportType.income:
        final data = await service.incomeReport(
          userId,
          startPeriod: _startDate,
          endPeriod: _endDate,
          accountId: _accountId,
          categoryId: _categoryId,
        );
        return (records: data.rows.length, income: data.total, expense: 0.0);
      case ReportType.expense:
        final data = await service.expenseReport(
          userId,
          startDate: _startDate,
          endDate: _endDate,
          accountId: _accountId,
          categoryId: _categoryId,
        );
        return (records: data.transactions.length, income: 0.0, expense: data.total);
      case ReportType.category:
        final data = await service.categoryReport(
          userId,
          startDate: _startDate,
          endDate: _endDate,
        );
        return (
          records: data.incomeByCategory.length + data.expenseByCategory.length,
          income: data.totalIncome,
          expense: data.totalExpense,
        );
      case ReportType.loansDebts:
        final data = await service.loanDebtReport(userId);
        return (
          records: data.owedToYou.length + data.youOwe.length,
          income: data.totalOwedToYou,
          expense: data.totalYouOwe,
        );
      case ReportType.annual:
        final data = await service.annualReport(userId, _year);
        return (records: data.monthly.length, income: data.totalIncome, expense: data.totalExpense);
    }
  }

  Future<void> _export(String format) async {
    if (_isExporting) return;
    if (_reportType.requiresAccount && _accountId == null) {
      context.showErrorSnackBar('Please select an account');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final calcService = ref.read(reportCalculationServiceProvider);
      final filename = _filename(format);

      if (_reportType == ReportType.transactionStatement) {
        // Reuses the existing transaction-list export directly — see
        // TransactionExportService.
        final data = await calcService.transactionReport(
          user.uid,
          type: _type,
          accountId: _accountId,
          categoryId: _categoryId,
          startDate: _startDate,
          endDate: _endDate,
        );

        if (!mounted) return;
        if (data.transactions.isEmpty) {
          context.showErrorSnackBar('No transactions found for the selected filters');
          return;
        }

        final exportService = ref.read(transactionExportServiceProvider);
        if (format == 'excel') {
          final bytes = exportService.buildExcel(
            data.transactions,
            accountsById: data.accountsById,
            categoriesById: data.categoriesById,
          );
          downloadFile(bytes, filename, mimeType: _xlsxMime);
        } else {
          final bytes = await exportService.buildPdf(
            data.transactions,
            accountsById: data.accountsById,
            categoriesById: data.categoriesById,
            filterDescription: _periodLabel(),
          );
          downloadFile(bytes, filename, mimeType: 'application/pdf');
        }
      } else {
        final pdfService = ref.read(pdfReportServiceProvider);
        final excelService = ref.read(excelReportServiceProvider);
        final bytes = await _buildReportBytes(calcService, pdfService, excelService, user.uid, format);
        if (bytes == null) {
          if (mounted) context.showErrorSnackBar('Nothing to export for the selected filters');
          return;
        }
        downloadFile(bytes, filename, mimeType: format == 'excel' ? _xlsxMime : 'application/pdf');
      }

      if (mounted) context.showSuccessSnackBar('Report downloaded');
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Export failed: ${ErrorMessages.from(e)}');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  static const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Future<Uint8List?> _buildReportBytes(
    ReportCalculationService calcService,
    PdfReportService pdfService,
    ExcelReportService excelService,
    String userId,
    String format,
  ) async {
    switch (_reportType) {
      case ReportType.monthly:
        final data = await calcService.monthlyReport(userId, _month);
        return format == 'excel'
            ? excelService.buildMonthlyReport(data)
            : await pdfService.buildMonthlyReport(data);
      case ReportType.accountStatement:
        final data = await calcService.accountStatement(
          userId,
          _accountId!,
          startDate: _startDate,
          endDate: _endDate,
        );
        return format == 'excel'
            ? excelService.buildAccountStatement(data)
            : await pdfService.buildAccountStatement(data);
      case ReportType.income:
        final data = await calcService.incomeReport(
          userId,
          startPeriod: _startDate,
          endPeriod: _endDate,
          accountId: _accountId,
          categoryId: _categoryId,
        );
        if (data.rows.isEmpty) return null;
        return format == 'excel'
            ? excelService.buildIncomeReport(data)
            : await pdfService.buildIncomeReport(data);
      case ReportType.expense:
        final data = await calcService.expenseReport(
          userId,
          startDate: _startDate,
          endDate: _endDate,
          accountId: _accountId,
          categoryId: _categoryId,
        );
        if (data.transactions.isEmpty) return null;
        return format == 'excel'
            ? excelService.buildExpenseReport(data)
            : await pdfService.buildExpenseReport(data);
      case ReportType.category:
        final data = await calcService.categoryReport(
          userId,
          startDate: _startDate,
          endDate: _endDate,
        );
        return format == 'excel'
            ? excelService.buildCategoryReport(data)
            : await pdfService.buildCategoryReport(data);
      case ReportType.loansDebts:
        final data = await calcService.loanDebtReport(userId);
        return format == 'excel'
            ? excelService.buildLoanDebtReport(data)
            : await pdfService.buildLoanDebtReport(data);
      case ReportType.annual:
        final data = await calcService.annualReport(userId, _year);
        return format == 'excel'
            ? excelService.buildAnnualReport(data)
            : await pdfService.buildAnnualReport(data);
      case ReportType.transactionStatement:
        throw StateError('handled separately');
    }
  }

  String _periodLabel() {
    if (_reportType.usesSingleMonth) return DateTimeUtils.formatMonthYear(_month);
    if (_reportType.usesYear) return '$_year';
    if (_startDate != null && _endDate != null) {
      return '${DateTimeUtils.formatDate(_startDate!)} - ${DateTimeUtils.formatDate(_endDate!)}';
    }
    return 'All time';
  }

  String _filename(String format) {
    final extension = format == 'excel' ? 'xlsx' : 'pdf';
    final period = switch (_reportType) {
      ReportType.monthly => DateTimeUtils.formatMonthYear(_month).replaceAll(' ', '_'),
      ReportType.annual => '$_year',
      _ => () {
          final now = DateTime.now();
          return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        }(),
    };
    final base = switch (_reportType) {
      ReportType.monthly => 'Monthly_Report_$period',
      ReportType.transactionStatement => 'Transactions_$period',
      ReportType.accountStatement =>
        '${_sanitize(_accountName())}_Statement_$period',
      ReportType.income => 'Income_Report_$period',
      ReportType.expense => 'Expense_Report_$period',
      ReportType.category => 'Category_Report_$period',
      ReportType.loansDebts => 'Loans_Debts_Report_$period',
      ReportType.annual => 'Annual_Report_$period',
    };
    return 'EazyVault_$base.$extension';
  }

  String _sanitize(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

  String _accountName() {
    final accounts = ref.read(accountsNotifierProvider).maybeWhen<List<AccountModel>>(
          loaded: (accounts) => accounts,
          orElse: () => <AccountModel>[],
        );
    for (final account in accounts) {
      if (account.id == _accountId) return account.name;
    }
    return 'Account';
  }

  // ---- date/month/year pickers ----

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(
      context: context,
      initialMonth: _month,
      lastMonth: DateTime(DateTime.now().year + 1, DateTime.now().month),
    );
    if (picked != null) {
      setState(() => _month = picked);
      _refreshPreview();
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: _defaultStartDate(), end: now),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      _refreshPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final accountsState = ref.watch(accountsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);

    final accounts = accountsState.maybeWhen<List<AccountModel>>(
      loaded: (accounts) => accounts,
      orElse: () => <AccountModel>[],
    );
    final categories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (categories) => categories.where((c) => c.isActive).toList(),
      orElse: () => <CategoryModel>[],
    );

    final content = SingleChildScrollView(
      padding: AppSpacing.paddingMD,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_reportType.description, style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurface.withOpacity(0.6))),
          AppSpacing.gapMD,
          ..._buildFilters(accounts, categories),
          AppSpacing.gapMD,
          _buildPreview(),
          if (_error != null) ...[
            AppSpacing.gapSM,
            Text(_error!, style: TextStyle(color: context.colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
    );

    final actions = Padding(
      padding: AppSpacing.paddingMD,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isExporting ? null : () => _export('pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          ),
          AppSpacing.gapSM,
          Expanded(
            child: FilledButton.icon(
              onPressed: _isExporting ? null : () => _export('excel'),
              icon: _isExporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_chart_outlined),
              label: const Text('Excel'),
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(_reportType.displayName),
            actions: [
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          body: SafeArea(top: false, child: content),
          bottomNavigationBar: SafeArea(minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: actions),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.formMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
              child: BrandedDialogTitle(
                title: Text(_reportType.displayName),
                actions: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Flexible(child: content),
            const Divider(height: 1),
            actions,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilters(List<AccountModel> accounts, List<CategoryModel> categories) {
    final widgets = <Widget>[];

    if (_reportType.usesSingleMonth) {
      widgets.add(_pickerField(
        label: 'Month',
        value: DateTimeUtils.formatMonthYear(_month),
        icon: Icons.calendar_month_outlined,
        onTap: _pickMonth,
      ));
    }

    if (_reportType.usesYear) {
      widgets.add(DropdownButtonFormField<int>(
        value: _year,
        decoration: const InputDecoration(labelText: 'Year', prefixIcon: Icon(Icons.calendar_today_outlined)),
        items: [
          for (var y = DateTime.now().year; y >= DateTime.now().year - 10; y--)
            DropdownMenuItem(value: y, child: Text('$y')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _year = value);
          _refreshPreview();
        },
      ));
    }

    if (_reportType.usesDateRange) {
      widgets.add(_pickerField(
        label: 'Date Range',
        value: _startDate != null && _endDate != null
            ? '${DateTimeUtils.formatDate(_startDate!)} - ${DateTimeUtils.formatDate(_endDate!)}'
            : 'Select a range',
        icon: Icons.date_range_outlined,
        onTap: _pickDateRange,
      ));
    }

    if (_reportType.requiresAccount || _reportType.supportsAccountFilter) {
      widgets.add(AppSpacing.gapMD);
      widgets.add(DropdownButtonFormField<String>(
        isExpanded: true,
        value: _accountId,
        decoration: InputDecoration(
          labelText: _reportType.requiresAccount ? 'Account' : 'Account (optional)',
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        items: [
          if (!_reportType.requiresAccount) const DropdownMenuItem(value: null, child: Text('All Accounts')),
          ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (value) {
          setState(() => _accountId = value);
          _refreshPreview();
        },
      ));
    }

    if (_reportType.supportsCategoryFilter) {
      widgets.add(AppSpacing.gapMD);
      widgets.add(DropdownButtonFormField<String?>(
        isExpanded: true,
        value: _categoryId,
        decoration: const InputDecoration(labelText: 'Category (optional)', prefixIcon: Icon(Icons.category_outlined)),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
          ...categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (value) {
          setState(() => _categoryId = value);
          _refreshPreview();
        },
      ));
    }

    if (_reportType.supportsTypeFilter) {
      widgets.add(AppSpacing.gapMD);
      widgets.add(Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _type == null,
            onSelected: (_) {
              setState(() => _type = null);
              _refreshPreview();
            },
          ),
          ChoiceChip(
            label: const Text('Income'),
            selected: _type == TransactionType.income,
            onSelected: (_) {
              setState(() => _type = TransactionType.income);
              _refreshPreview();
            },
          ),
          ChoiceChip(
            label: const Text('Expense'),
            selected: _type == TransactionType.expense,
            onSelected: (_) {
              setState(() => _type = TransactionType.expense);
              _refreshPreview();
            },
          ),
        ],
      ));
    }

    return widgets;
  }

  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusLG,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }

  Widget _buildPreview() {
    if (_reportType.requiresAccount && _accountId == null) {
      return Text(
        'Select an account to see a preview.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
      );
    }
    if (_isLoadingPreview) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: LoadingIndicator(size: 24)),
      );
    }
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: AppSpacing.borderRadiusLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Records: ${preview.records}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (preview.income > 0) Text('Income: ${CurrencyUtils.format(preview.income)}', style: const TextStyle(color: Colors.green)),
          if (preview.expense > 0) Text('Expense: ${CurrencyUtils.format(preview.expense)}', style: const TextStyle(color: Colors.red)),
          if (preview.income > 0 || preview.expense > 0)
            Text(
              'Net: ${CurrencyUtils.formatWithSign(preview.income - preview.expense)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
