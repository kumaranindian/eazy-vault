import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/list_dialog.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/enums/category_type.dart';
import '../../data/models/category_model.dart';
import '../providers/categories_notifier.dart';
import '../widgets/add_category_modal.dart';
import '../widgets/category_card.dart';

class CategoriesModal extends ConsumerStatefulWidget {
  const CategoriesModal({super.key});

  @override
  ConsumerState<CategoriesModal> createState() => _CategoriesModalState();
}

class _CategoriesModalState extends ConsumerState<CategoriesModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _seedDefaults() async {
    setState(() => _isSeeding = true);
    final failure = await ref
        .read(categoriesNotifierProvider.notifier)
        .seedDefaultCategories();
    if (!mounted) return;
    setState(() => _isSeeding = false);

    if (failure == null) {
      ref.invalidate(categoriesNotifierProvider);
      context.showSuccessSnackBar('Default categories loaded successfully');
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

  void _showAddCategory() {
    showDialog<void>(
      context: context,
      builder: (context) => const AddCategoryModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesNotifierProvider);
    final hasCategories = categoriesState.maybeWhen(
      loaded: (categories) => categories.isNotEmpty,
      orElse: () => false,
    );

    return ListDialog(
      title: 'All Categories',
      body: categoriesState.when(
        initial: () => const LoadingIndicator(),
        loading: () => const LoadingIndicator(),
        error: (failure) => ErrorView(
          message: failure.message,
          onRetry: () => ref.read(categoriesNotifierProvider.notifier).refresh(),
        ),
        loaded: (categories) {
          if (categories.isEmpty) {
            return SingleChildScrollView(
              child: EmptyState(
                title: 'No Categories Yet',
                message: 'Load default categories to get started',
                iconData: Icons.category_outlined,
              ),
            );
          }

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Income'),
                  Tab(text: 'Expense'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCategoryList(
                      context,
                      categories.where((c) => c.type == CategoryType.income).toList(),
                    ),
                    _buildCategoryList(
                      context,
                      categories.where((c) => c.type == CategoryType.expense).toList(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        if (hasCategories)
          FilledButton.icon(
            onPressed: _showAddCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          )
        else if (categoriesState.maybeWhen(loaded: (_) => true, orElse: () => false)) ...[
          TextButton.icon(
            onPressed: _isSeeding ? null : _showAddCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Category'),
          ),
          FilledButton.icon(
            onPressed: _isSeeding ? null : _seedDefaults,
            icon: _isSeeding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isSeeding ? 'Loading...' : 'Load Default Categories'),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryList(BuildContext context, List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          title: 'No categories found',
          iconData: Icons.category_outlined,
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingMD,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < categories.length - 1 ? 8 : 0,
          ),
          child: CategoryCard(
            category: category,
            onTap: () {
              Navigator.of(context).pop();
              context.push(
                RouteConstants.editCategory.replaceAll(':id', category.id),
              );
            },
          ),
        );
      },
    );
  }
}
