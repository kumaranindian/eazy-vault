import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../../core/widgets/branded_dialog_title.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/utils/error_messages.dart';

class AddAccountModal extends ConsumerStatefulWidget {
  const AddAccountModal({super.key});

  @override
  ConsumerState<AddAccountModal> createState() => _AddAccountModalState();
}

class _AddAccountModalState extends ConsumerState<AddAccountModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _descriptionController = TextEditingController();

  AccountType _selectedType = AccountType.cash;
  int _selectedColor = AppColors.accountColors[0].value;
  String _selectedIcon = '💰';
  bool _isActive = true;
  bool _isLoading = false;
  bool _savingAnother = false;

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
        context.showErrorSnackBar(ErrorMessages.sessionExpired);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _savingAnother = addAnother;
    });

    final openingBalance = double.parse(_openingBalanceController.text.trim());
    final now = DateTime.now();

    final account = AccountModel(
      id: '',
      name: _nameController.text.trim(),
      type: _selectedType,
      openingBalance: openingBalance,
      currentBalance: openingBalance,
      color: _selectedColor,
      icon: _selectedIcon,
      isActive: _isActive,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: user.uid,
    );

    final failure = await ref.read(accountsNotifierProvider.notifier).createAccount(account);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (failure == null) {
      context.showSuccessSnackBar('Account created successfully');
      ref.invalidate(accountsNotifierProvider);
      
      if (addAnother) {
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
        Navigator.of(context).pop();
      }
    } else {
      context.showErrorSnackBar(failure.message);
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

  /// Local duplicate check against the already-loaded list, so the user
  /// sees it next to the field instead of after a round trip.
  String? _duplicateNameError(String? value) {
    final name = value?.trim().toLowerCase() ?? '';
    final existing = ref.read(accountsNotifierProvider).maybeWhen<List<AccountModel>>(
      loaded: (items) => items,
      orElse: () => <AccountModel>[],
    );
    final taken = existing.any(
      (e) => e.name.trim().toLowerCase() == name,
    );
    return taken ? 'An account with this name already exists' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: BrandedDialogTitle(
        title: const Text('Add Account'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: Breakpoints.formMaxWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Account Name',
                  hint: 'e.g., Main Savings',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  validator: (value) =>
                      Validators.name(value, fieldName: 'Account name') ?? _duplicateNameError(value),
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
                  helperText: 'Initial amount in this account',
                  prefixIcon: const Icon(Icons.account_balance),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: Validators.amount,
                  enabled: !_isLoading,
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
                            const Flexible(child: Text('Color', overflow: TextOverflow.ellipsis)),
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
                            const Flexible(child: Text('Icon', overflow: TextOverflow.ellipsis)),
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
              onPressed: _isLoading ? null : () => _handleSave(addAnother: true),
              icon: _isLoading && _savingAnother ? const _Spinner() : const Icon(Icons.add),
              label: Text(_isLoading && _savingAnother ? 'Saving...' : 'Save and Add Another'),
            ),
            AppSpacing.gapSM,
            FilledButton.icon(
              onPressed: _isLoading ? null : () => _handleSave(),
              icon: _isLoading && !_savingAnother ? const _Spinner() : const Icon(Icons.save),
              label: Text(_isLoading && !_savingAnother ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
