import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/categories_notifier.dart';
import '../providers/dashboard_providers.dart';

/// A single slice of the breakdown: either a real category or the "Other"
/// bucket collecting categories past [_maxSlices].
class _Slice {
  const _Slice({
    required this.label,
    required this.icon,
    required this.color,
    required this.amount,
  });

  final String label;
  final String icon;
  final Color color;
  final double amount;
}

const int _maxSlices = 6;

class CategoryBreakdownChart extends ConsumerStatefulWidget {
  const CategoryBreakdownChart({super.key});

  @override
  ConsumerState<CategoryBreakdownChart> createState() => _CategoryBreakdownChartState();
}

class _CategoryBreakdownChartState extends ConsumerState<CategoryBreakdownChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final categoryExpensesAsync = ref.watch(categoryExpensesProvider);
    final categoriesState = ref.watch(categoriesNotifierProvider);

    final categoriesById = categoriesState.maybeWhen<Map<String, CategoryModel>>(
      loaded: (categories) => {for (final category in categories) category.id: category},
      orElse: () => const {},
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_large, color: context.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Category Breakdown',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'This Month',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            categoryExpensesAsync.when(
              data: (expensesByCategory) {
                final slices = _buildSlices(expensesByCategory, categoriesById);
                if (slices.isEmpty) {
                  return const _EmptyState();
                }
                return _buildBody(context, slices);
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Failed to load category breakdown',
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Slice> _buildSlices(
    Map<String, double> expensesByCategory,
    Map<String, CategoryModel> categoriesById,
  ) {
    final entries = expensesByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const [];

    final topEntries = entries.take(_maxSlices);
    final otherTotal = entries
        .skip(_maxSlices)
        .fold<double>(0, (sum, e) => sum + e.value);

    final slices = topEntries.map((entry) {
      final category = categoriesById[entry.key];
      return _Slice(
        label: category?.name ?? 'Other',
        icon: category?.icon ?? '📦',
        color: category != null ? Color(category.color) : Colors.grey,
        amount: entry.value,
      );
    }).toList();

    if (otherTotal > 0) {
      slices.add(_Slice(
        label: 'Other',
        icon: '📦',
        color: Colors.grey,
        amount: otherTotal,
      ));
    }

    return slices;
  }

  Widget _buildBody(BuildContext context, List<_Slice> slices) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.amount);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Column(
      children: [
        SizedBox(
          height: isMobile ? 200 : 240,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: isMobile ? 48 : 60,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: [
                for (int i = 0; i < slices.length; i++)
                  _buildSection(slices[i], total, isTouched: i == _touchedIndex),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLegend(context, slices, total),
      ],
    );
  }

  PieChartSectionData _buildSection(_Slice slice, double total, {required bool isTouched}) {
    final percent = total > 0 ? (slice.amount / total) * 100 : 0.0;
    final baseRadius = isTouched ? 66.0 : 56.0;

    return PieChartSectionData(
      value: slice.amount,
      color: slice.color,
      radius: baseRadius,
      title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegend(BuildContext context, List<_Slice> slices, double total) {
    return Column(
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: slice.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(slice.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slice.label,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  CurrencyUtils.format(slice.amount),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    total > 0 ? '${((slice.amount / total) * 100).toStringAsFixed(0)}%' : '0%',
                    textAlign: TextAlign.end,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.donut_large,
              size: 48,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No expenses this month',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
