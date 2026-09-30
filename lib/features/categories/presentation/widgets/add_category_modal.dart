import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/adaptive_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../accounts/presentation/widgets/color_picker_dialog.dart';
import '../../../accounts/presentation/widgets/icon_picker_dialog.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/category_model.dart';
import '../../domain/enums/category_type.dart';
import '../providers/categories_notifier.dart';

class AddCategoryModal extends ConsumerStatefulWidget {
  const AddCategoryModal({super.key});

  @override
  ConsumerState<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends ConsumerState<AddCategoryModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  CategoryType _selectedType = CategoryType.expense;
  int _selectedColor = 0xFFFF5722;
  String _selectedIcon = '💸';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
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

    final now = DateTime.now();

    final category = CategoryModel(
      id: '',
      name: _nameController.text.trim(),
      type: _selectedType,
      color: _selectedColor,
      icon: _selectedIcon,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isDefault: false,
      isActive: _isActive,
      createdAt: now,
      updatedAt: now,
      createdBy: user.uid,
    );

    final failure = await ref.read(categoriesNotifierProvider.notifier).createCategory(category);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (failure == null) {
      context.showSuccessSnackBar('Category created successfully');
      ref.invalidate(categoriesNotifierProvider);
      
      if (addAnother) {
        // Clear form for adding another category
        _nameController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedType = CategoryType.expense;
          _selectedColor = 0xFFFF5722;
          _selectedIcon = '💸';
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

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormDialog(
      title: 'Add Category',
      isLoading: _isLoading,
      content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMD,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Category Name',
                  hint: 'e.g., Food & Dining',
                  prefixIcon: const Icon(Icons.category_outlined),
                  validator: (value) => Validators.name(value, fieldName: 'Category name'),
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.words,
                ),
                AppSpacing.gapMD,
                DropdownButtonFormField<CategoryType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Category Type',
                    prefixIcon: Icon(Icons.swap_vert),
                  ),
                  items: CategoryType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
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
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Add a note about this category',
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
                  subtitle: const Text('Enable or disable this category'),
                  value: _isActive,
                  onChanged: _isLoading ? null : (value) => setState(() => _isActive = value),
                  contentPadding: EdgeInsets.zero,
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
              onPressed: _isLoading ? null : () => _handleSave(addAnother: true),
              icon: const Icon(Icons.add),
              label: const Text('Save and Add Another'),
            ),
            AppSpacing.gapSM,
            FilledButton.icon(
              onPressed: _isLoading ? null : () => _handleSave(),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
