import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../accounts/presentation/widgets/color_picker_dialog.dart';
import '../../../accounts/presentation/widgets/icon_picker_dialog.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/category_model.dart';
import '../../domain/enums/category_type.dart';
import '../providers/categories_notifier.dart';

class AddEditCategoryPage extends ConsumerStatefulWidget {
  const AddEditCategoryPage({
    super.key,
    this.categoryId,
  });

  final String? categoryId;

  @override
  ConsumerState<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends ConsumerState<AddEditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  CategoryType _selectedType = CategoryType.expense;
  int _selectedColor = 0xFFFF5722;
  String _selectedIcon = '💸';
  bool _isActive = true;
  bool _isLoading = false;
  CategoryModel? _existingCategory;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _loadCategory();
    }
  }

  Future<void> _loadCategory() async {
    final category = await ref.read(categoryProvider(widget.categoryId!).future);
    if (category != null && mounted) {
      setState(() {
        _existingCategory = category;
        _nameController.text = category.name;
        _descriptionController.text = category.description ?? '';
        _selectedType = category.type;
        _selectedColor = category.color;
        _selectedIcon = category.icon;
        _isActive = category.isActive;
      });
    }
  }

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
      id: _existingCategory?.id ?? '',
      name: _nameController.text.trim(),
      type: _selectedType,
      color: _selectedColor,
      icon: _selectedIcon,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isDefault: _existingCategory?.isDefault ?? false,
      isActive: _isActive,
      createdAt: _existingCategory?.createdAt ?? now,
      updatedAt: now,
      createdBy: user.uid,
    );

    final success = _existingCategory == null
        ? await ref.read(categoriesNotifierProvider.notifier).createCategory(category)
        : await ref.read(categoriesNotifierProvider.notifier).updateCategory(category);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.showSuccessSnackBar(
        _existingCategory == null
            ? 'Category created successfully'
            : 'Category updated successfully',
      );
      
      if (addAnother && _existingCategory == null) {
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
        context.pop();
      }
    } else {
      final categoriesState = ref.read(categoriesNotifierProvider);
      categoriesState.whenOrNull(
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
    final isEditing = _existingCategory != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Category' : 'Add Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingMD,
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
            if (_existingCategory?.isDefault == true) ...[
              AppSpacing.gapSM,
              Container(
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: AppSpacing.borderRadiusLG,
                  border: Border.all(
                    color: context.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.colorScheme.primary,
                      size: 20,
                    ),
                    AppSpacing.gapSM,
                    Expanded(
                      child: Text(
                        'This is a default category',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    : const Text('Update Category'),
              ),
          ],
        ),
      ),
    );
  }
}
