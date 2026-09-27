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
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _icons.length,
          itemBuilder: (context, index) {
            final icon = _icons[index];
            final isSelected = _selectedIcon == icon;

            return InkWell(
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
