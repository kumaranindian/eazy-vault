import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/services/account_balance_service.dart';
import '../providers/transactions_notifier.dart';

class AddEditTransactionPage extends ConsumerStatefulWidget {
  const AddEditTransactionPage({
    super.key,
    this.transactionId,
    this.initialType,
  });

  final String? transactionId;
  final TransactionType? initialType;

  @override
  ConsumerState<AddEditTransactionPage> createState() =>
      _AddEditTransactionPageState();
}

class _AddEditTransactionPageState
    extends ConsumerState<AddEditTransactionPage> {
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
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    if (widget.transactionId != null) {
      _loadTransaction();
    }
  }

  Future<void> _loadTransaction() async {
    final transaction =
        await ref.read(transactionProvider(widget.transactionId!).future);
    if (transaction != null && mounted) {
      if (!AccountBalanceService.isEditableType(transaction.type)) {
        context.showErrorSnackBar(
          'Transfers and loans cannot be edited. Delete and re-create them instead.',
        );
        context.pop();
        return;
      }
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

    final amount = double.parse(_amountController.text.trim());
    final now = DateTime.now();
    final description = _descriptionController.text.trim();
    final vendor = _vendorController.text.trim();
    final attachment = _attachmentController.text.trim();

    // When editing, start from the stored record so fields this form doesn't
    // show (e.g. metadata) are preserved.
    final transaction = _existingTransaction?.copyWith(
          type: _selectedType,
          amount: amount,
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          description: description.isEmpty ? null : description,
          vendor: vendor.isEmpty ? null : vendor,
          attachments: attachment.isEmpty ? null : [attachment],
          updatedAt: now,
        ) ??
        TransactionModel(
      id: '',
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
      createdAt: _existingTransaction?.createdAt ?? now,
      updatedAt: now,
      createdBy: user.uid,
    );

    final failure = _existingTransaction == null
        ? await ref
            .read(transactionsNotifierProvider.notifier)
            .createTransaction(transaction)
        : await ref
            .read(transactionsNotifierProvider.notifier)
            .updateTransaction(transaction);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (failure == null) {
      context.showSuccessSnackBar(
        _existingTransaction == null
            ? '${_selectedType.displayName} added successfully'
            : 'Transaction updated successfully',
      );
      context.pop();
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingTransaction != null;
    final accountsState = ref.watch(accountsNotifierProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);

    // Keep the currently selected account/category selectable even if it has
    // since been deactivated, otherwise the dropdown has no matching item.
    final activeAccounts = accountsState.maybeWhen<List<AccountModel>>(
      loaded: (accounts) => accounts
          .where((a) => a.isActive || a.id == _selectedAccountId)
          .toList(),
      orElse: () => <AccountModel>[],
    );

    final filteredCategories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (categories) {
        // Convert TransactionType to CategoryType for comparison
        final categoryType = _selectedType == TransactionType.income
            ? CategoryType.income
            : CategoryType.expense;
        return categories
            .where((c) =>
                c.type == categoryType &&
                (c.isActive || c.id == _selectedCategoryId))
            .toList();
      },
      orElse: () => <CategoryModel>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Transaction'
              : 'Add ${_selectedType.displayName}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingMD,
          children: [
            if (!isEditing) ...[
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
            ],
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
              validator: Validators.positiveAmount,
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
            AppSpacing.gapXL,
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEditing ? 'Update Transaction' : 'Add ${_selectedType.displayName}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
