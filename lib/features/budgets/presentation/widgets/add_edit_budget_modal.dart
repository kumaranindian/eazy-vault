import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/adaptive_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../../data/models/budget_model.dart';
import '../providers/budgets_notifier.dart';

/// Add/edit a monthly budget for one expense category. The category can't be
/// changed once a budget exists for it — delete and re-create instead, same
/// convention as transfers/loans not being editable.
class AddEditBudgetModal extends ConsumerStatefulWidget {
  const AddEditBudgetModal({super.key, this.budget});

  final BudgetModel? budget;

  @override
  ConsumerState<AddEditBudgetModal> createState() => _AddEditBudgetModalState();
}

class _AddEditBudgetModalState extends ConsumerState<AddEditBudgetModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedCategoryId;
  bool _isLoading = false;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    if (budget != null) {
      _selectedCategoryId = budget.categoryId;
      _amountController.text = budget.amount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
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
    final notifier = ref.read(budgetsNotifierProvider.notifier);
    final existingBudget = widget.budget;

    final failure = existingBudget != null
        ? await notifier.updateBudget(
            existingBudget.copyWith(amount: amount, updatedAt: now),
          )
        : await notifier.createBudget(
            BudgetModel(
              id: '',
              categoryId: _selectedCategoryId!,
              amount: amount,
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
        _isEditing ? 'Budget updated successfully' : 'Budget created successfully',
      );
      Navigator.of(context).pop();
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final budgetsState = ref.watch(budgetsNotifierProvider);

    // A category can only have one active budget; exclude ones already
    // budgeted (except the one this edit is already for).
    final alreadyBudgetedCategoryIds = budgetsState.maybeWhen<Set<String>>(
      loaded: (budgets) => budgets
          .where((b) => b.isActive && b.id != widget.budget?.id)
          .map((b) => b.categoryId)
          .toSet(),
      orElse: () => const {},
    );

    final availableCategories = expenseCategories
        .where((c) => !alreadyBudgetedCategoryIds.contains(c.id))
        .toList();

    return AdaptiveFormDialog(
      title: _isEditing ? 'Edit Budget' : 'Add Budget',
      isLoading: _isLoading,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingMD,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  helperText: availableCategories.isEmpty && !_isEditing
                      ? 'All expense categories already have a budget'
                      : null,
                ),
                items: availableCategories.map((category) {
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
                // The category can't be changed once a budget exists for it.
                onChanged: _isLoading || _isEditing
                    ? null
                    : (value) => setState(() => _selectedCategoryId = value),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              AppSpacing.gapMD,
              AppTextField(
                controller: _amountController,
                label: 'Monthly Limit',
                hint: '0.00',
                prefixIcon: const Icon(Icons.currency_rupee),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: Validators.positiveAmount,
                enabled: !_isLoading,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('${RouteConstants.userManual}?section=budgets');
                  },
                  child: const Text('Learn how budget alerts work →'),
                ),
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
              label: Text(_isEditing ? 'Update Budget' : 'Save Budget'),
            ),
          ],
        ),
      ],
    );
  }
}
