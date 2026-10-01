import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/adaptive_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../domain/enums/recurrence_frequency.dart';
import '../providers/recurring_transactions_notifier.dart';

/// Add/edit a recurring income/expense rule. Transfers and loans aren't
/// supported as recurring rules for now, same scope as the quick-add
/// transaction dialog.
class AddEditRecurringModal extends ConsumerStatefulWidget {
  const AddEditRecurringModal({super.key, this.rule});

  final RecurringTransactionModel? rule;

  @override
  ConsumerState<AddEditRecurringModal> createState() => _AddEditRecurringModalState();
}

class _AddEditRecurringModalState extends ConsumerState<AddEditRecurringModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    if (rule != null) {
      _selectedType = rule.type;
      _selectedAccountId = rule.accountId;
      _selectedCategoryId = rule.categoryId;
      _amountController.text = rule.amount.toString();
      _descriptionController.text = rule.description ?? '';
      _vendorController.text = rule.vendor ?? '';
      _frequency = rule.frequency;
      _startDate = rule.startDate;
      _endDate = rule.endDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null || _selectedCategoryId == null) {
      context.showErrorSnackBar('Please select account and category');
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
    final description = _descriptionController.text.trim();
    final vendor = _vendorController.text.trim();
    final notifier = ref.read(recurringTransactionsNotifierProvider.notifier);
    final existingRule = widget.rule;

    final failure = existingRule != null
        ? await notifier.updateRule(
            existingRule.copyWith(
              type: _selectedType,
              amount: amount,
              accountId: _selectedAccountId!,
              categoryId: _selectedCategoryId!,
              description: description.isEmpty ? null : description,
              vendor: vendor.isEmpty ? null : vendor,
              frequency: _frequency,
              startDate: _startDate,
              endDate: _endDate,
              updatedAt: now,
            ),
          )
        : await notifier.createRule(
            RecurringTransactionModel(
              id: '',
              type: _selectedType,
              amount: amount,
              accountId: _selectedAccountId!,
              categoryId: _selectedCategoryId!,
              description: description.isEmpty ? null : description,
              vendor: vendor.isEmpty ? null : vendor,
              frequency: _frequency,
              startDate: _startDate,
              endDate: _endDate,
              isActive: true,
              createdAt: now,
              updatedAt: now,
              createdBy: user.uid,
            ),
          );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (failure == null) {
      context.showSuccessSnackBar(
        _isEditing ? 'Recurring transaction updated successfully' : 'Recurring transaction created successfully',
      );
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
      loaded: (accounts) => accounts
          .where((a) => a.isActive || a.id == _selectedAccountId)
          .toList(),
      orElse: () => <AccountModel>[],
    );

    final filteredCategories = categoriesState.maybeWhen<List<CategoryModel>>(
      loaded: (categories) {
        final categoryType =
            _selectedType == TransactionType.income ? CategoryType.income : CategoryType.expense;
        return categories
            .where((c) => c.type == categoryType && (c.isActive || c.id == _selectedCategoryId))
            .toList();
      },
      orElse: () => <CategoryModel>[],
    );

    return AdaptiveFormDialog(
      title: _isEditing ? 'Edit Recurring Transaction' : 'Add Recurring Transaction',
      isLoading: _isLoading,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingMD,
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
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) {
                        setState(() {
                          _selectedType = selection.first;
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                validator: (value) => value == null ? 'Please select an account' : null,
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
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              AppSpacing.gapMD,
              DropdownButtonFormField<RecurrenceFrequency>(
                value: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Repeats',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: RecurrenceFrequency.values.map((frequency) {
                  return DropdownMenuItem(
                    value: frequency,
                    child: Text(frequency.displayName),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) setState(() => _frequency = value);
                      },
              ),
              AppSpacing.gapMD,
              InkWell(
                onTap: _isLoading ? null : _selectStartDate,
                borderRadius: AppSpacing.borderRadiusLG,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                ),
              ),
              AppSpacing.gapMD,
              InkWell(
                onTap: _isLoading ? null : _selectEndDate,
                borderRadius: AppSpacing.borderRadiusLG,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date (Optional)',
                    prefixIcon: const Icon(Icons.event_busy_outlined),
                    suffixIcon: _endDate == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _isLoading ? null : () => setState(() => _endDate = null),
                            tooltip: 'Clear end date',
                          ),
                  ),
                  child: Text(
                    _endDate == null
                        ? 'No end date'
                        : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                  ),
                ),
              ),
              AppSpacing.gapMD,
              AppTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hint: 'e.g., Monthly rent',
                prefixIcon: const Icon(Icons.notes_outlined),
                maxLines: 3,
                validator: (value) => Validators.description(value),
                enabled: !_isLoading,
              ),
              AppSpacing.gapMD,
              AppTextField(
                controller: _vendorController,
                label: 'Vendor (Optional)',
                hint: 'e.g., Landlord',
                prefixIcon: const Icon(Icons.store_outlined),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length > 100) {
                    return 'Vendor name must be less than 100 characters';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
            ],
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
              label: Text(_isEditing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ],
    );
  }
}
