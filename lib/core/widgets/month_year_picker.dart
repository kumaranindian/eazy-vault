import 'package:flutter/material.dart';

/// A simple month+year picker — Flutter has no built-in one, and a day-level
/// `showDatePicker` doesn't fit fields like "Income For" that only need a
/// calendar month. Returns the first day of the chosen month, or `null` if
/// cancelled.
Future<DateTime?> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialMonth,
  DateTime? firstMonth,
  DateTime? lastMonth,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _MonthYearPickerDialog(
      initialMonth: DateTime(initialMonth.year, initialMonth.month),
      firstMonth: firstMonth,
      lastMonth: lastMonth,
    ),
  );
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({
    required this.initialMonth,
    this.firstMonth,
    this.lastMonth,
  });

  final DateTime initialMonth;
  final DateTime? firstMonth;
  final DateTime? lastMonth;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _month = widget.initialMonth.month;
  late int _year = widget.initialMonth.year;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final firstYear = widget.firstMonth?.year ?? _year - 10;
    final lastYear = widget.lastMonth?.year ?? _year + 10;
    final years = [for (var y = firstYear; y <= lastYear; y++) y];

    return AlertDialog(
      title: const Text('Select Month'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _month,
              decoration: const InputDecoration(labelText: 'Month'),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
              ],
              onChanged: (value) => setState(() => _month = value ?? _month),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _year,
              decoration: const InputDecoration(labelText: 'Year'),
              items: [
                for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (value) => setState(() => _year = value ?? _year),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DateTime(_year, _month)),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
