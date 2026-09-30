import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/breakpoints.dart';

/// Dialog shell for forms opened with [showDialog]. The width is capped on
/// wide screens, fills narrow screens, and the height is limited by the
/// visible viewport ([Dialog] already subtracts the on-screen keyboard), so
/// the form's own scroll view keeps every field and the submit button
/// reachable in landscape and with the keyboard open.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.formMaxWidth,
  });

  /// Should scroll itself (e.g. a [SingleChildScrollView] around its fields).
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Less padding on phones so fields keep usable width.
    final padding = MediaQuery.sizeOf(context).width < Breakpoints.mobile
        ? AppSpacing.paddingMD
        : AppSpacing.paddingLG;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
