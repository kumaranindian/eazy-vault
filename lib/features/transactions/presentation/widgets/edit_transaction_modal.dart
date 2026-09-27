import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../providers/transactions_notifier.dart';

class EditTransactionModal extends ConsumerStatefulWidget {
  const EditTransactionModal({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<EditTransactionModal> createState() => _EditTransactionModalState();
}

class _EditTransactionModalState extends ConsumerState<EditTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorController = TextEditingController();
  final _attachmentController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  TransactionModel? _existingTransaction;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final transaction =
        await ref.read(transactionProvider(widget.transactionId).future);
    if (transaction != null && mounted) {
      setState(() {
        _existingTransaction = transaction;
        _selectedType = transaction.type;
        _amountController.text = transaction.amount.toString();
        _selectedAccountId = transaction.accountId;
        _selectedCategoryId = transaction.categoryId;
        _selectedDate = transaction.date;
        _descriptionController.text = transaction.description ?? '';
        _vendorController.text = transaction.vendor ?? '';
        if (transaction.attachments != null &&
            transaction.attachments!.isNotEmpty) {
          _attachmentController.text = transaction.attachments!.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null) {
      context.showErrorSnackBar('Please select an account');
      return;
    }

    if (_selectedCategoryId == null) {
      context.showErrorSnackBar('Please select a category');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _isLoading = false);
      context.showErrorSnackBar('Invalid amount');
      return;
    }

    final now = DateTime.now();

    final transaction = TransactionModel(
      id: _existingTransaction!.id,
      type: _selectedType,
      amount: amount,
      accountId: _selectedAccountId!,
      categoryId: _selectedCategoryId!,
      date: _selectedDate,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      vendor: _vendorController.text.trim().isEmpty
          ? null
          : _vendorController.text.trim(),
      attachments: _attachmentController.text.trim().isEmpty
          ? null
          : [_attachmentController.text.trim()],
      createdAt: _existingTransaction!.createdAt,
      updatedAt: now,
      createdBy: user.uid,
    );

    final success = await ref
        .read(transactionsNotifierProvider.notifier)
        .updateTransaction(transaction, _existingTransaction);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(currentMonthStatsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(recentTransactionsProvider);
      
      context.showSuccessSnackBar('Transaction updated successfully');
      Navigator.of(context).pop();
    } else {
      final transactionsState = ref.read(transactionsNotifierProvider);
      transactionsState.whenOrNull(
        error: (failure) => context.showErrorSnackBar(failure.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);

    final activeAccounts = accountsState.maybeWhen(
      loaded: (accounts) => accounts.where((a) => a.isActive).toList(),
      orElse: () => [],
    );

    final filteredCategories = categoriesState.maybeWhen(
      loaded: (categories) {
        final categoryType = _selectedType == TransactionType.income
            ? CategoryType.income
            : CategoryType.expense;
        return categories
            .where((c) => c.type == categoryType && c.isActive)
            .toList();
      },
      orElse: () => [],
    );

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
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
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
            'Edit Transaction',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<TransactionType> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                      _selectedCategoryId = null;
                    });
                  },
                ),
                AppSpacing.gapMD,
                AppTextField(
                  controller: _amountController,
                  label: 'Amount',
                  hint: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: Validators.amount,
                  enabled: !_isLoading,
                ),
                AppSpacing.gapMD,
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: activeAccounts.map((account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Row(
                        children: [
                          Text(account.icon),
                          AppSpacing.gapSM,
                          Text(account.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _selectedAccountId = value),
                  validator: (value) =>
                      value == null ? 'Please select an account' : null,
                ),
                AppSpacing.gapMD,
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    helperText: filteredCategories.isEmpty
                        ? 'No categories available for ${_selectedType.displayName}'
                        : null,
                  ),
                  items: filteredCategories.map((category) {
                    return DropdownMenuItem<String>(
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
                  onChanged: _isLoading || filteredCategories.isEmpty
                      ? null
                      : (value) => setState(() => _selectedCategoryId = value),
                  validator: (value) =>
                      value == null ? 'Please select a category' : null,
                ),
                AppSpacing.gapMD,
                InkWell(
                  onTap: _isLoading ? null : _selectDate,
                  borderRadius: AppSpacing.borderRadiusLG,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                  ),
                ),
                AppSpacing.gapMD,
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'What was this transaction for?',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  maxLines: 3,
                  validator: (value) => Validators.description(value),
                  enabled: !_isLoading,
                ),
                AppSpacing.gapMD,
                AppTextField(
                  controller: _vendorController,
                  label: 'Vendor (Optional)',
                  hint: 'Where did you spend?',
                  prefixIcon: const Icon(Icons.store_outlined),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length > 100) {
                      return 'Vendor name must be less than 100 characters';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                AppSpacing.gapMD,
                AppTextField(
                  controller: _attachmentController,
                  label: 'Attachment URL (Optional)',
                  hint: 'https://example.com/receipt.jpg',
                  prefixIcon: const Icon(Icons.attach_file_outlined),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final urlPattern = RegExp(
                        r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
                      );
                      if (!urlPattern.hasMatch(value)) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _isLoading ? null : _handleSave,
              icon: const Icon(Icons.save),
              label: const Text('Update Transaction'),
            ),
          ],
        ),
      ],
    );
  }
}
