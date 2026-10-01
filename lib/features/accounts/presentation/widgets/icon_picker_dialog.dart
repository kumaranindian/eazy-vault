import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({
    super.key,
    required this.selectedIcon,
  });

  final String selectedIcon;

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  late String _selectedIcon;

  static const List<String> _icons = [
    '💰',
    '💵',
    '💳',
    '🏦',
    '🏢',
    '📱',
    '💼',
    '👛',
    '🪙',
    '💎',
    '🏠',
    '🚗',
    '✈️',
    '🎓',
    '🏥',
    '🛒',
    '🍔',
    '☕',
    '🎬',
    '🎮',
    '📚',
    '⚽',
    '🎵',
    '🎨',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Icon'),
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
          itemCount: _icons.length,
          itemBuilder: (context, index) {
            final icon = _icons[index];
            final isSelected = _selectedIcon == icon;

            return Semantics(
              label: 'Icon $icon',
              selected: isSelected,
              button: true,
              child: InkWell(
              onTap: () => setState(() => _selectedIcon = icon),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
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
          onPressed: () => Navigator.of(context).pop(_selectedIcon),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
