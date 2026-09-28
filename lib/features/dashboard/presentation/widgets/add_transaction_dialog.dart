import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/presentation/providers/transactions_notifier.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
  const AddTransactionDialog({
    super.key,
    required this.type,
    this.showDialog = true,
  });

  final TransactionType type;
  final bool showDialog;

  @override
  ConsumerState<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorController = TextEditingController();
  final _attachmentController = TextEditingController();
  
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null || _selectedCategoryId == null) {
      if (mounted) {
        context.showErrorSnackBar('Please select account and category');
      }
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
      id: '',
      type: widget.type,
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
      createdAt: now,
      updatedAt: now,
      createdBy: user.uid,
    );

    final failure = await ref
        .read(transactionsNotifierProvider.notifier)
        .createTransaction(transaction);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (failure == null) {
      context.showSuccessSnackBar('${widget.type.displayName} added successfully');
      Navigator.of(context).pop();
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);

    final activeAccounts = accountsState.maybeWhen<List<AccountModel>>(
      loaded: (accounts) => accounts.where((a) => a.isActive).toList(),
      orElse: () => <AccountModel>[],
    );

    final filteredCategories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (categories) {
        final categoryType = widget.type == TransactionType.income
            ? CategoryType.income
            : CategoryType.expense;
        return categories
            .where((c) => c.type == categoryType && c.isActive)
            .toList();
      },
      orElse: () => <CategoryModel>[],
    );

    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: isMobile ? AppSpacing.paddingMD : EdgeInsets.zero,
            child: SizedBox(
              width: isMobile ? double.infinity : 500,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _amountController,
                      label: 'Amount',
                      hint: '0.00',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            ? 'No categories available for ${widget.type.displayName}'
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
        ),
      ],
    );

    final actionsRow = Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        AppSpacing.gapSM,
        Expanded(
          child: FilledButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Add ${widget.type.displayName}'),
          ),
        ),
      ],
    );

    if (!widget.showDialog) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          AppSpacing.gapMD,
          actionsRow,
        ],
      );
    }

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text('Add ${widget.type.displayName}')),
          body: SafeArea(top: false, child: content),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: actionsRow,
          ),
        ),
      );
    }

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
            'Add ${widget.type.displayName}',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: content,
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
          : Text('Add ${widget.type.displayName}'),
        ),
      ],
    );
  }
}
