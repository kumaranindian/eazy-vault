import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/sign_out_button.dart';
import '../../domain/enums/category_type.dart';
import '../providers/categories_notifier.dart';
import '../widgets/category_card.dart';
import '../../../../core/widgets/responsive_layout.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSeeding = false;

  /// Guarded so repeated taps can't seed the defaults twice.
  Future<void> _seedDefaults() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);
    final failure = await ref
        .read(categoriesNotifierProvider.notifier)
        .seedDefaultCategories();
    if (!mounted) return;
    setState(() => _isSeeding = false);
    if (failure == null) {
      context.showSuccessSnackBar('Default categories loaded successfully');
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

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
            onPressed: () =>
                ref.read(categoriesNotifierProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
          PopupMenuButton(
            tooltip: 'More options',
            enabled: !_isSeeding,
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
            onSelected: (value) {
              if (value == 'seed') _seedDefaults();
            },
          ),
          const SignOutButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
      ),
      body: Column(
        children: [
          const PageHeader(
            title: 'Categories',
            description: 'Organize your income and expenses.',
          ),
          Expanded(
            child: categoriesState.when(
              initial: () => const LoadingIndicator(),
              loading: () => const LoadingIndicator(),
              error: (failure) => ErrorView(
                message: failure.message,
                onRetry: () =>
                    ref.read(categoriesNotifierProvider.notifier).refresh(),
              ),
              loaded: (categories) {
                if (categories.isEmpty) {
                  if (_isSeeding) return const LoadingIndicator(size: 32);
                  return EmptyState(
                    title: 'No Categories Yet',
                    message:
                        'Load default categories or create your own to organize transactions',
                    iconData: Icons.category_outlined,
                    action: _seedDefaults,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteConstants.addCategory),
        tooltip: 'Add category',
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
      child: ResponsiveContent(
        maxWidth: 800,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            88, // clear of the FAB
          ),
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
      ),
    );
  }
}
