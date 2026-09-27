import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/account_model.dart';
import '../../domain/enums/account_type.dart';
import '../providers/accounts_notifier.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/icon_picker_dialog.dart';

class AddEditAccountPage extends ConsumerStatefulWidget {
  const AddEditAccountPage({
    super.key,
    this.accountId,
  });

  final String? accountId;

  @override
  ConsumerState<AddEditAccountPage> createState() => _AddEditAccountPageState();
}

class _AddEditAccountPageState extends ConsumerState<AddEditAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _descriptionController = TextEditingController();

  AccountType _selectedType = AccountType.cash;
  int _selectedColor = AppColors.accountColors[0].value;
  String _selectedIcon = '💰';
  bool _isActive = true;
  bool _isLoading = false;
  AccountModel? _existingAccount;

  @override
  void initState() {
    super.initState();
    if (widget.accountId != null) {
      _loadAccount();
    }
  }

  Future<void> _loadAccount() async {
    final account = await ref.read(accountProvider(widget.accountId!).future);
    if (account != null && mounted) {
      setState(() {
        _existingAccount = account;
        _nameController.text = account.name;
        _openingBalanceController.text = account.openingBalance.toString();
        _descriptionController.text = account.description ?? '';
        _selectedType = account.type;
        _selectedColor = account.color;
        _selectedIcon = account.icon;
        _isActive = account.isActive;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) {
        context.showErrorSnackBar('User not authenticated');
      }
      return;
    }

    setState(() => _isLoading = true);

    final openingBalance = double.parse(_openingBalanceController.text.trim());
    final now = DateTime.now();

    final account = AccountModel(
      id: _existingAccount?.id ?? '',
      name: _nameController.text.trim(),
      type: _selectedType,
      openingBalance: openingBalance,
      currentBalance: _existingAccount?.currentBalance ?? openingBalance,
      color: _selectedColor,
      icon: _selectedIcon,
      isActive: _isActive,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: _existingAccount?.createdAt ?? now,
      updatedAt: now,
      createdBy: user.uid,
    );

    final success = _existingAccount == null
        ? await ref.read(accountsNotifierProvider.notifier).createAccount(account)
        : await ref.read(accountsNotifierProvider.notifier).updateAccount(account);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.showSuccessSnackBar(
        _existingAccount == null
            ? 'Account created successfully'
            : 'Account updated successfully',
      );
      
      if (addAnother && _existingAccount == null) {
        // Clear form for adding another account
        _nameController.clear();
        _openingBalanceController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedType = AccountType.cash;
          _selectedColor = AppColors.accountColors[0].value;
          _selectedIcon = '💰';
          _isActive = true;
        });
      } else {
        context.pop();
      }
    } else {
      final accountsState = ref.read(accountsNotifierProvider);
      accountsState.whenOrNull(
        error: (failure) => context.showErrorSnackBar(failure.message),
      );
    }
  }

  Future<void> _showColorPicker() async {
    final color = await showDialog<int>(
      context: context,
      builder: (context) => ColorPickerDialog(selectedColor: _selectedColor),
    );

    if (color != null) {
      setState(() => _selectedColor = color);
    }
  }

  Future<void> _showIconPicker() async {
    final icon = await showDialog<String>(
      context: context,
      builder: (context) => IconPickerDialog(selectedIcon: _selectedIcon),
    );

    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingAccount != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Account' : 'Add Account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingMD,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Account Name',
              hint: 'e.g., Main Savings',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              validator: (value) => Validators.name(value, fieldName: 'Account name'),
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
            ),
            AppSpacing.gapMD,
            DropdownButtonFormField<AccountType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Account Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: AccountType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Text(type.icon),
                      AppSpacing.gapSM,
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
            ),
            AppSpacing.gapMD,
            AppTextField(
              controller: _openingBalanceController,
              label: 'Opening Balance',
              hint: '0.00',
              helperText: isEditing 
                  ? 'Opening balance cannot be changed after creation'
                  : 'Initial amount in this account',
              prefixIcon: const Icon(Icons.account_balance),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: Validators.amount,
              enabled: !_isLoading && !isEditing,
            ),
            AppSpacing.gapMD,
            AppTextField(
              controller: _descriptionController,
              label: 'Description (Optional)',
              hint: 'Add a note about this account',
              prefixIcon: const Icon(Icons.notes_outlined),
              maxLines: 3,
              validator: (value) => Validators.description(value),
              enabled: !_isLoading,
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _showColorPicker,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(_selectedColor),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        ),
                        AppSpacing.gapSM,
                        const Text('Color'),
                      ],
                    ),
                  ),
                ),
                AppSpacing.gapMD,
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _showIconPicker,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_selectedIcon, style: const TextStyle(fontSize: 24)),
                        AppSpacing.gapSM,
                        const Text('Icon'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapMD,
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Enable or disable this account'),
              value: _isActive,
              onChanged: _isLoading ? null : (value) => setState(() => _isActive = value),
              contentPadding: EdgeInsets.zero,
            ),
            AppSpacing.gapXL,
            if (!isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _handleSave(addAnother: true),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save and Add Another'),
                    ),
                  ),
                  AppSpacing.gapMD,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _handleSave(),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ] else
              ElevatedButton(
                onPressed: _isLoading ? null : () => _handleSave(),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Account'),
              ),
          ],
        ),
      ),
    );
  }
}
