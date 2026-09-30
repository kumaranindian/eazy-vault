import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.selectedColor,
  });

  final int selectedColor;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Color'),
      // Fixed-size swatches: a sensible width on desktop (double.maxFinite
      // stretched them across the screen) that still shrinks on phones.
      content: SizedBox(
        width: 360,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: AppColors.accountColors.length,
          itemBuilder: (context, index) {
            final color = AppColors.accountColors[index];
            final isSelected = _selectedColor == color.value;

            return Semantics(
              label: 'Color ${index + 1}',
              selected: isSelected,
              button: true,
              child: InkWell(
              onTap: () => setState(() => _selectedColor = color.value),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      )
                    : null,
              ),
            ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppSpacing.gapSM,
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
