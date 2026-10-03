import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/models/net_worth_point.dart';
import '../providers/net_worth_provider.dart';

enum _RangePreset { week, month, quarter, year, custom }

class NetWorthChart extends ConsumerStatefulWidget {
  const NetWorthChart({super.key});

  @override
  ConsumerState<NetWorthChart> createState() => _NetWorthChartState();
}

class _NetWorthChartState extends ConsumerState<NetWorthChart> {
  _RangePreset _preset = _RangePreset.month;
  DateTimeRange? _customRange;

  ({DateTime start, DateTime end}) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case _RangePreset.week:
        return (start: today.subtract(const Duration(days: 6)), end: today);
      case _RangePreset.month:
        return (start: DateTime(today.year, today.month - 1, today.day), end: today);
      case _RangePreset.quarter:
        return (start: DateTime(today.year, today.month - 3, today.day), end: today);
      case _RangePreset.year:
        // Treated the same as a fiscal year — this app has no separate
        // fiscal-year configuration anywhere else.
        return (start: DateTime(today.year - 1, today.month, today.day), end: today);
      case _RangePreset.custom:
        final range = _customRange;
        if (range == null) return (start: DateTime(today.year, today.month - 1, today.day), end: today);
        return (start: range.start, end: range.end);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _preset = _RangePreset.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final historyAsync = ref.watch(
      netWorthHistoryProvider(startDate: range.start, endDate: range.end),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: context.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Net Worth',
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                historyAsync.maybeWhen(
                  data: (points) => points.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          CurrencyUtils.format(points.last.netWorth),
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.primary,
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _rangeChip('This Week', _RangePreset.week),
                _rangeChip('This Month', _RangePreset.month),
                _rangeChip('This Quarter', _RangePreset.quarter),
                _rangeChip('This Year', _RangePreset.year),
                ChoiceChip(
                  label: Text(
                    _preset == _RangePreset.custom && _customRange != null
                        ? '${DateFormat('d MMM').format(_customRange!.start)} - '
                            '${DateFormat('d MMM').format(_customRange!.end)}'
                        : 'Custom',
                  ),
                  selected: _preset == _RangePreset.custom,
                  onSelected: (_) => _pickCustomRange(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            historyAsync.when(
              data: (points) {
                if (points.length < 2 || points.every((p) => p.netWorth == points.first.netWorth)) {
                  if (points.isEmpty) return _buildEmpty(context);
                }
                return SizedBox(
                  height: context.isMobile ? 200 : 260,
                  child: LineChart(_buildChartData(context, points)),
                );
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load net worth history',
                        style: TextStyle(color: context.colorScheme.error),
                      ),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(
                          netWorthHistoryProvider(startDate: range.start, endDate: range.end),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(String label, _RangePreset preset) {
    return ChoiceChip(
      label: Text(label),
      selected: _preset == preset,
      onSelected: (_) => setState(() => _preset = preset),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'No account history for this range',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context, List<NetWorthPoint> points) {
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].netWorth),
    ];
    final values = points.map((p) => p.netWorth);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs();
    final interval = span > 0 ? span / 4 : 100.0;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: (points.length / 5).ceilToDouble().clamp(1, points.length.toDouble()),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= points.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('d MMM').format(points[index].date),
                  style: context.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: interval,
            getTitlesWidget: (value, meta) => Text(
              CurrencyUtils.formatCompact(value),
              style: context.textTheme.bodySmall,
            ),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
          left: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      minY: minValue < 0 ? minValue * 1.1 : minValue * 0.95,
      maxY: maxValue * 1.05,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            return LineTooltipItem(
              CurrencyUtils.format(spot.y),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: context.colorScheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: context.colorScheme.primary.withOpacity(0.1),
          ),
        ),
      ],
    );
  }
}
