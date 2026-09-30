import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/utils/web_download.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../providers/transactions_notifier.dart';
import '../providers/transactions_providers.dart';
import 'transaction_card.dart';
import 'transaction_detail_modal.dart';
import 'edit_transaction_modal.dart';

enum DateFilter {
  thisWeek,
  thisMonth,
  thisQuarter,
  thisFiscalYear,
  custom,
}

extension DateFilterExtension on DateFilter {
  String get displayName {
    switch (this) {
      case DateFilter.thisWeek:
        return 'This Week';
      case DateFilter.thisMonth:
        return 'This Month';
      case DateFilter.thisQuarter:
        return 'This Quarter';
      case DateFilter.thisFiscalYear:
        return 'This Fiscal Year';
      case DateFilter.custom:
        return 'Custom Range';
    }
  }

  ({DateTime startDate, DateTime endDate}) getDateRange() {
    final now = DateTime.now();
    switch (this) {
      case DateFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return (
          startDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DateFilter.thisMonth:
        return (
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case DateFilter.thisQuarter:
        final quarter = ((now.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        return (
          startDate: DateTime(now.year, startMonth, 1),
          endDate: DateTime(now.year, startMonth + 3, 0, 23, 59, 59),
        );
      case DateFilter.thisFiscalYear:
        // Assuming fiscal year starts in April
        final fiscalYearStart = now.month >= 4
            ? DateTime(now.year, 4, 1)
            : DateTime(now.year - 1, 4, 1);
        final fiscalYearEnd = now.month >= 4
            ? DateTime(now.year + 1, 3, 31, 23, 59, 59)
            : DateTime(now.year, 3, 31, 23, 59, 59);
        return (startDate: fiscalYearStart, endDate: fiscalYearEnd);
      case DateFilter.custom:
        return (startDate: now, endDate: now);
    }
  }
}

class TransactionsModal extends ConsumerStatefulWidget {
  const TransactionsModal({super.key});

  @override
  ConsumerState<TransactionsModal> createState() => _TransactionsModalState();
}

class _TransactionsModalState extends ConsumerState<TransactionsModal> {
  TransactionType? _selectedType;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateFilter _selectedDateFilter = DateFilter.thisMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  void _applyFilters() {
    final notifier = ref.read(transactionsNotifierProvider.notifier);
    
    DateTime? startDate;
    DateTime? endDate;

    if (_selectedDateFilter != DateFilter.custom) {
      final range = _selectedDateFilter.getDateRange();
      startDate = range.startDate;
      endDate = range.endDate;
    } else {
      startDate = _customStartDate;
      // The picker returns midnight; include the whole last day.
      final end = _customEndDate;
      endDate = end == null
          ? null
          : DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    }

    notifier.applyFilters(
      type: _selectedType,
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedAccountId = null;
      _selectedCategoryId = null;
      _selectedDateFilter = DateFilter.thisMonth;
      _customStartDate = null;
      _customEndDate = null;
    });
    _applyFilters();
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedDateFilter = DateFilter.custom;
      });
      _applyFilters();
    }
  }

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref, TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final failure = await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transaction.id, transaction);
      if (failure == null && context.mounted) {
        context.showSuccessSnackBar('Transaction deleted successfully');
      } else if (failure != null && context.mounted) {
        context.showErrorSnackBar(failure.message);
      }
    }
  }

  void _editTransaction(BuildContext context, TransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => EditTransactionModal(transactionId: transaction.id),
    );
  }

  void _showTransactionDetailModal(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (context) => TransactionDetailModal(transactionId: transactionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = Breakpoints.isMobile(screenWidth);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('All Transactions'),
            actions: [_buildExportButton()],
          ),
          body: _buildBody(context, isMobile: true),
        ),
      );
    }

    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

    final double dialogWidth = isTablet ? screenWidth * 0.85 : screenWidth * 0.7;
    final double dialogHeight = isTablet ? screenHeight * 0.85 : screenHeight * 0.8;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppConfig.appName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppConfig.appTagline,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'All Transactions',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _buildBody(context, isMobile: false),
      ),
      actions: [_buildExportButton()],
    );
  }

  Widget _buildExportButton() {
    if (_isExporting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.file_download_outlined),
      tooltip: 'Export',
      onSelected: _exportTransactions,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'csv',
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('Export as CSV'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Export as PDF'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  String _filterDescription() {
    final typeLabel = _selectedType?.displayName ?? 'All Transactions';
    return '$typeLabel — ${_selectedDateFilter.displayName}';
  }

  Future<void> _exportTransactions(String format) async {
    if (_isExporting) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() => _isExporting = true);

    try {
      DateTime? startDate;
      DateTime? endDate;

      if (_selectedDateFilter != DateFilter.custom) {
        final range = _selectedDateFilter.getDateRange();
        startDate = range.startDate;
        endDate = range.endDate;
      } else {
        startDate = _customStartDate;
        final end = _customEndDate;
        endDate = end == null
            ? null
            : DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
      }

      final result = await ref.read(transactionsRepositoryProvider).getTransactions(
            user.uid,
            type: _selectedType,
            accountId: _selectedAccountId,
            categoryId: _selectedCategoryId,
            startDate: startDate,
            endDate: endDate,
            limit: 5000,
          );

      if (result.failure != null) {
        if (mounted) context.showErrorSnackBar(result.failure!.message);
        return;
      }

      if (result.transactions.isEmpty) {
        if (mounted) context.showErrorSnackBar('No transactions to export');
        return;
      }

      final accountsById = ref.read(accountsNotifierProvider).maybeWhen<Map<String, AccountModel>>(
            loaded: (accounts) => {for (final account in accounts) account.id: account},
            orElse: () => const {},
          );
      final categoriesById =
          ref.read(categoriesNotifierProvider).maybeWhen<Map<String, CategoryModel>>(
                loaded: (categories) => {for (final category in categories) category.id: category},
                orElse: () => const {},
              );

      final exportService = ref.read(transactionExportServiceProvider);
      final now = DateTime.now();
      final filenameStamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';

      if (format == 'csv') {
        final csv = exportService.buildCsv(
          result.transactions,
          accountsById: accountsById,
          categoriesById: categoriesById,
        );
        downloadFile(
          Uint8List.fromList(utf8.encode(csv)),
          'eazyvault-transactions-$filenameStamp.csv',
          mimeType: 'text/csv',
        );
      } else {
        final pdfBytes = await exportService.buildPdf(
          result.transactions,
          accountsById: accountsById,
          categoriesById: categoriesById,
          filterDescription: _filterDescription(),
        );
        downloadFile(
          pdfBytes,
          'eazyvault-transactions-$filenameStamp.pdf',
          mimeType: 'application/pdf',
        );
      }

      if (mounted) {
        context.showSuccessSnackBar('${result.transactions.length} transactions exported');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Export failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildBody(BuildContext context, {required bool isMobile}) {
    final transactionsState = ref.watch(transactionsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);
    final accountsState = ref.watch(accountsNotifierProvider);

    final categories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (cats) => cats.where((c) => c.isActive).toList(),
      orElse: () => <CategoryModel>[],
    );

    return Column(
      children: [
        // Filters
        Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: context.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Type Filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Wrap(
                          spacing: isMobile ? 4 : 8,
                          runSpacing: isMobile ? 4 : 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _selectedType == null,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedType = null;
                                    _selectedCategoryId = null;
                                  });
                                  _applyFilters();
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_upward, size: 16),
                                  SizedBox(width: 4),
                                  Text('Income'),
                                ],
                              ),
                              selected: _selectedType == TransactionType.income,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedType = TransactionType.income;
                                    _selectedCategoryId = null;
                                  });
                                  _applyFilters();
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_downward, size: 16),
                                  SizedBox(width: 4),
                                  Text('Expense'),
                                ],
                              ),
                              selected: _selectedType == TransactionType.expense,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedType = TransactionType.expense;
                                    _selectedCategoryId = null;
                                  });
                                  _applyFilters();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapMD,

                  // Date Filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: isMobile ? 200 : 300,
                          child: DropdownButtonFormField<DateFilter>(
                            value: _selectedDateFilter,
                            decoration: const InputDecoration(
                              labelText: 'Date Range',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: DateFilter.values.map((filter) {
                              return DropdownMenuItem(
                                value: filter,
                                child: Text(filter.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == DateFilter.custom) {
                                _selectCustomDateRange();
                              } else {
                                setState(() => _selectedDateFilter = value!);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                        if (_selectedDateFilter == DateFilter.custom) ...[
                          AppSpacing.gapSM,
                          IconButton(
                            icon: const Icon(Icons.edit_calendar),
                            onPressed: _selectCustomDateRange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.gapMD,

                  // Account Filter
                  accountsState.maybeWhen(
                    loaded: (accounts) {
                      final activeAccounts = accounts.where((a) => a.isActive).toList();
                      if (activeAccounts.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SizedBox(
                              width: isMobile ? 200 : 300,
                              child: DropdownButtonFormField<String>(
                                value: _selectedAccountId,
                                decoration: const InputDecoration(
                                  labelText: 'Account',
                                  prefixIcon: Icon(Icons.account_balance_wallet),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Accounts'),
                                  ),
                                  ...activeAccounts.map((account) {
                                    return DropdownMenuItem(
                                      value: account.id,
                                      child: Row(
                                        children: [
                                          Text(account.icon),
                                          const SizedBox(width: 8),
                                          Text(account.name),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedAccountId = value);
                                  _applyFilters();
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  AppSpacing.gapMD,

                  // Category Filter
                  if (categories.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                            width: isMobile ? 200 : 300,
                            child: DropdownButtonFormField<String?>(
                              value: _selectedCategoryId,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Categories'),
                                ),
                                ...categories
                                    .where((c) {
                                      if (_selectedType == null) return true;
                                      // Convert TransactionType to CategoryType for comparison
                                      final categoryType = _selectedType == TransactionType.income
                                          ? CategoryType.income
                                          : CategoryType.expense;
                                      return c.type == categoryType;
                                    })
                                    .map((category) {
                                  return DropdownMenuItem<String?>(
                                    value: category.id,
                                    child: Row(
                                      children: [
                                        Text(category.icon),
                                        AppSpacing.gapSM,
                                        Text(category.name),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCategoryId = value);
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  AppSpacing.gapMD,

                  // Clear Filters Button
                  if (_selectedType != null ||
                      _selectedAccountId != null ||
                      _selectedCategoryId != null ||
                      _selectedDateFilter != DateFilter.thisMonth)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                ),
              ),
            ),

            // Transactions List
            Expanded(
              child: transactionsState.when(
                initial: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (failure) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: context.colorScheme.error,
                      ),
                      AppSpacing.gapMD,
                      Text(
                        failure.message,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapMD,
                      FilledButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                loaded: (transactions, hasMore, _) {
                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: context.colorScheme.outline,
                          ),
                          AppSpacing.gapMD,
                          Text(
                            'No transactions found',
                            style: context.textTheme.titleMedium,
                          ),
                          AppSpacing.gapSM,
                          Text(
                            'Try adjusting your filters',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 8 : 16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return TransactionCard(
                        transaction: transaction,
                        onTap: () => _showTransactionDetailModal(context, transaction.id),
                        onDelete: () => _deleteTransaction(context, ref, transaction),
                        onEdit: () => _editTransaction(context, transaction),
                      );
                    },
                  );
                },
                loadingMore: (transactions, hasMore, _) {
                  return ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 8 : 16),
                    itemCount: transactions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == transactions.length) {
                        return const Center(
                          child: Padding(
                            padding: AppSpacing.paddingMD,
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final transaction = transactions[index];
                      return TransactionCard(
                        transaction: transaction,
                        onTap: () => _showTransactionDetailModal(context, transaction.id),
                        onDelete: () => _deleteTransaction(context, ref, transaction),
                        onEdit: () => _editTransaction(context, transaction),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
  }
}
