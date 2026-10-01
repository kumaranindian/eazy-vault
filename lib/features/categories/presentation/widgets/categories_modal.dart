import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
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
  bool _hasCategories = false;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = Breakpoints.isMobile(screenWidth);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('All Categories'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Income'),
                Tab(text: 'Expense'),
              ],
            ),
          ),
          body: _buildBody(context),
          floatingActionButton: _hasCategories
              ? FloatingActionButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddCategoryModal(),
                    );
                  },
                  tooltip: 'Add Category',
                  child: const Icon(Icons.add),
                )
              : null,
        ),
      );
    }

    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

    final double dialogWidth = isTablet ? screenWidth * 0.85 : screenWidth * 0.7;
    final double dialogHeight = isTablet ? screenHeight * 0.85 : screenHeight * 0.8;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppConfig.appName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppConfig.appTagline,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'All Categories',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Income'),
                Tab(text: 'Expense'),
              ],
            ),
            // Categories List
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_hasCategories)
              FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddCategoryModal(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final categoriesState = ref.watch(categoriesNotifierProvider);

    return categoriesState.when(
      initial: () => const LoadingIndicator(),
      loading: () => const LoadingIndicator(),
      error: (failure) => ErrorView(
        message: failure.message,
        onRetry: () => ref.read(categoriesNotifierProvider.notifier).refresh(),
      ),
      loaded: (categories) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _hasCategories != categories.isNotEmpty) {
            setState(() => _hasCategories = categories.isNotEmpty);
          }
        });

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: context.colorScheme.outline,
                ),
                AppSpacing.gapMD,
                Text(
                  'No Categories Yet',
                  style: context.textTheme.titleMedium,
                ),
                AppSpacing.gapSM,
                Text(
                  'Load default categories to get started',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapXL,
                FilledButton.icon(
                  onPressed: () async {
                    final failure = await ref
                        .read(categoriesNotifierProvider.notifier)
                        .seedDefaultCategories();

                    if (failure == null && context.mounted) {
                      ref.invalidate(categoriesNotifierProvider);
                      context.showSuccessSnackBar('Default categories loaded successfully');
                    } else if (context.mounted) {
                      context.showErrorSnackBar(failure?.message);
                    }
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Load Default Categories'),
                ),
                AppSpacing.gapMD,
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddCategoryModal(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Custom Category'),
                ),
              ],
            ),
          );
        }

        return TabBarView(
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
        );
      },
    );
  }

  Widget _buildCategoryList(BuildContext context, List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: context.colorScheme.outline,
            ),
            AppSpacing.gapMD,
            Text(
              'No categories found',
              style: context.textTheme.titleMedium,
            ),
          ],
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
