import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';
import '../theme/app_colors.dart';

const double _snackBarMaxWidth = 480;

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => theme.textTheme;

  ColorScheme get colorScheme => theme.colorScheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  // sizeOf only rebuilds on size changes (rotation, resize), not on every
  // MediaQuery change such as keyboard insets.
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;

  double get screenHeight => screenSize.height;

  EdgeInsets get padding => mediaQuery.padding;

  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  bool get isMobile => Breakpoints.isMobile(screenWidth);

  bool get isTablet => Breakpoints.isTablet(screenWidth);

  bool get isDesktop => Breakpoints.isDesktop(screenWidth);

  bool get isMobileOrTablet => Breakpoints.isMobileOrTablet(screenWidth);

  bool get isTabletOrDesktop => Breakpoints.isTabletOrDesktop(screenWidth);

  /// Short viewport: landscape phone or a phone in desktop-site mode.
  bool get isCompactHeight => Breakpoints.isCompactHeight(screenHeight);

  bool get isDarkMode => theme.brightness == Brightness.dark;

  void showSnackBar(
    String message, {
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    // Replace instead of queueing, so repeated taps don't leave a backlog.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: foregroundColor == null
                ? null
                : TextStyle(color: foregroundColor),
          ),
          duration: duration ?? const Duration(seconds: 3),
          action: action,
          backgroundColor: backgroundColor,
          // Floating snackbars stretch edge to edge; keep them compact on
          // wide viewports (width requires floating behavior).
          behavior: SnackBarBehavior.floating,
          width: isMobile ? null : _snackBarMaxWidth,
        ),
      );
  }

  void showErrorSnackBar(String? message) {
    showSnackBar(
      message ?? 'An error occurred',
      duration: const Duration(seconds: 5),
      backgroundColor: colorScheme.error,
      foregroundColor: colorScheme.onError,
    );
  }

  void showSuccessSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: AppColors.success,
      foregroundColor: colorScheme.onPrimary,
    );
  }

  void showInfoSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    );
  }

  Future<T?> showBottomSheet<T>({
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => child,
    );
  }

  Future<T?> showAppDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: (context) => child,
    );
  }

  void popPage<T>([T? result]) {
    Navigator.of(this).pop(result);
  }

  bool get canPop => Navigator.of(this).canPop();
}
