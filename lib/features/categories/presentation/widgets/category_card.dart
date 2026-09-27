import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/models/category_model.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
  });

  final CategoryModel category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLG,
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(category.color).withOpacity(0.2),
                  borderRadius: AppSpacing.borderRadiusLG,
                ),
                child: Center(
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              AppSpacing.gapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (category.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (category.description != null) ...[
                      AppSpacing.gapXS,
                      Flexible(
                        child: Text(
                          category.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!category.isActive) ...[
                AppSpacing.gapSM,
                Icon(
                  Icons.visibility_off,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
