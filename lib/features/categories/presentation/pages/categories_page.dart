import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/enums/category_type.dart';
import '../providers/categories_notifier.dart';
import '../widgets/category_card.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(categoriesNotifierProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'seed',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 12),
                    Text('Load Default Categories'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'seed') {
                final failure = await ref
                    .read(categoriesNotifierProvider.notifier)
                    .seedDefaultCategories();

                if (failure == null && context.mounted) {
                  context.showSuccessSnackBar('Default categories loaded successfully');
                } else if (context.mounted) {
                  context.showErrorSnackBar(failure?.message);
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
      ),
      body: categoriesState.when(
        initial: () => const LoadingIndicator(),
        loading: () => const LoadingIndicator(),
        error: (failure) => ErrorView(
          message: failure.message,
          onRetry: () => ref.read(categoriesNotifierProvider.notifier).refresh(),
        ),
        loaded: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              title: 'No Categories Yet',
              message:
                  'Load default categories or create your own to organize transactions',
              iconData: Icons.category_outlined,
              action: () async {
                final failure = await ref
                    .read(categoriesNotifierProvider.notifier)
                    .seedDefaultCategories();

                if (failure == null && context.mounted) {
                  context.showSuccessSnackBar('Default categories loaded');
                }
              },
              actionLabel: 'Load Defaults',
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(CategoryType.income),
              _buildCategoryList(CategoryType.expense),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteConstants.addCategory),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(CategoryType type) {
    final categories = type == CategoryType.income
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);

    if (categories.isEmpty) {
      return EmptyState(
        title: 'No ${type.displayName} Categories',
        message: 'Create a category to get started',
        iconData: Icons.category_outlined,
        action: () => context.push(RouteConstants.addCategory),
        actionLabel: 'Add Category',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(categoriesNotifierProvider.notifier).refresh();
      },
      child: ListView.separated(
        padding: AppSpacing.paddingMD,
        itemCount: categories.length,
        separatorBuilder: (context, index) => AppSpacing.gapSM,
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryCard(
            category: category,
            onTap: () => context.push(
              RouteConstants.editCategory.replaceAll(':id', category.id),
            ),
          );
        },
      ),
    );
  }
}
