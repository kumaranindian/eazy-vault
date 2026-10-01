import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/widgets/branded_dialog_title.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/utils/web_download.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_layout.dart';
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
    final transactionsState = ref.watch(transactionsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);
    final accountsState = ref.watch(accountsNotifierProvider);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = context.isMobile;

    final categories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (cats) => cats.where((c) => c.isActive).toList(),
      orElse: () => <CategoryModel>[],
    );
    final activeAccounts = accountsState.maybeWhen<List<AccountModel>>(
      loaded: (accounts) => accounts.where((a) => a.isActive).toList(),
      orElse: () => <AccountModel>[],
    );

    // Filters and list share one scroll view, so on short viewports
    // (landscape phones) the filters scroll away instead of squeezing the
    // list to nothing. The dialog height follows the current viewport and
    // Dialog clamps it further when the keyboard is open.
    final listContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Load the next page when the user nears the end.
        final hasMore = transactionsState.maybeWhen(
          loaded: (_, hasMore, __) => hasMore,
          orElse: () => false,
        );
        if (hasMore &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          ref.read(transactionsNotifierProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildFilters(context, categories, activeAccounts, isMobile),
          ),
          ..._buildList(context, transactionsState, isMobile),
        ],
      ),
    );

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('All Transactions'),
            actions: [
              _buildExportButton(),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: SafeArea(top: false, child: listContent),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.listDialogMaxWidth),
        child: SizedBox(
          height: screenHeight * 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: BrandedDialogTitle(
                  title: const Text('All Transactions'),
                  actions: [
                    _buildExportButton(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(child: listContent),
            ],
          ),
        ),
      ),
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

  Widget _buildFilters(
    BuildContext context,
    List<CategoryModel> categories,
    List<AccountModel> activeAccounts,
    bool isMobile,
  ) {
    final hasActiveFilters = _selectedType != null ||
        _selectedAccountId != null ||
        _selectedCategoryId != null ||
        _selectedDateFilter != DateFilter.thisMonth;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                avatar: const Icon(Icons.arrow_upward, size: 16),
                label: const Text('Income'),
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
                avatar: const Icon(Icons.arrow_downward, size: 16),
                label: const Text('Expense'),
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
          AppSpacing.gapMD,
          // One column on phones, up to three side by side on wider screens.
          ResponsiveGrid(
            minItemWidth: 220,
            maxColumns: 3,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.md,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DateFilter>(
                      isExpanded: true,
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
                          child: Text(filter.displayName, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == DateFilter.custom) {
                          _selectCustomDateRange();
                        } else if (value != null) {
                          setState(() => _selectedDateFilter = value);
                          _applyFilters();
                        }
                      },
                    ),
                  ),
                  if (_selectedDateFilter == DateFilter.custom)
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      tooltip: 'Change date range',
                      onPressed: _selectCustomDateRange,
                    ),
                ],
              ),
              if (activeAccounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                            Expanded(
                              child: Text(account.name, overflow: TextOverflow.ellipsis),
                            ),
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
              if (categories.isNotEmpty)
                DropdownButtonFormField<String?>(
                  isExpanded: true,
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
                    ...categories.where((c) {
                      if (_selectedType == null) return true;
                      final categoryType = _selectedType == TransactionType.income
                          ? CategoryType.income
                          : CategoryType.expense;
                      return c.type == categoryType;
                    }).map((category) {
                      return DropdownMenuItem<String?>(
                        value: category.id,
                        child: Row(
                          children: [
                            Text(category.icon),
                            AppSpacing.gapSM,
                            Expanded(
                              child: Text(category.name, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCategoryId = value);
                    _applyFilters();
                  },
                ),
            ],
          ),
          if (hasActiveFilters) ...[
            AppSpacing.gapSM,
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildList(
    BuildContext context,
    TransactionsState transactionsState,
    bool isMobile,
  ) {
    final listPadding = EdgeInsets.all(isMobile ? 8 : 16);

    Widget card(TransactionModel transaction) => TransactionCard(
          transaction: transaction,
          onTap: () => _showTransactionDetailModal(context, transaction.id),
          onDelete: () => _deleteTransaction(context, ref, transaction),
          onEdit: () => _editTransaction(context, transaction),
        );

    Widget fill(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: child);

    return transactionsState.when(
      initial: () => [fill(const LoadingIndicator(size: 32))],
      loading: () => [fill(const LoadingIndicator(size: 32))],
      error: (failure) => [
        fill(ErrorView(message: failure.message, onRetry: _applyFilters)),
      ],
      loaded: (transactions, hasMore, _) {
        if (transactions.isEmpty) {
          return [
            fill(
              const EmptyState(
                title: 'No transactions found',
                message: 'Try adjusting your filters',
                iconData: Icons.receipt_long_outlined,
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: listPadding,
            sliver: SliverList.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) => card(transactions[index]),
            ),
          ),
        ];
      },
      loadingMore: (transactions, hasMore, _) => [
        SliverPadding(
          padding: listPadding,
          sliver: SliverList.builder(
            itemCount: transactions.length + 1,
            itemBuilder: (context, index) {
              if (index == transactions.length) {
                return const Padding(
                  padding: AppSpacing.paddingMD,
                  child: LoadingIndicator(),
                );
              }
              return card(transactions[index]);
            },
          ),
        ),
      ],
    );
  }
}
