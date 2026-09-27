import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => theme.textTheme;

  ColorScheme get colorScheme => theme.colorScheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => mediaQuery.size;

  double get screenWidth => screenSize.width;

  double get screenHeight => screenSize.height;

  EdgeInsets get padding => mediaQuery.padding;

  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  bool get isMobile => Breakpoints.isMobile(screenWidth);

  bool get isTablet => Breakpoints.isTablet(screenWidth);

  bool get isDesktop => Breakpoints.isDesktop(screenWidth);

  bool get isMobileOrTablet => Breakpoints.isMobileOrTablet(screenWidth);

  bool get isTabletOrDesktop => Breakpoints.isTabletOrDesktop(screenWidth);

  bool get isDarkMode => theme.brightness == Brightness.dark;

  void showSnackBar(
    String message, {
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
  }

  void showErrorSnackBar(String? message) {
    showSnackBar(
      message ?? 'An error occurred',
      duration: const Duration(seconds: 5),
      backgroundColor: colorScheme.error,
    );
  }

  void showSuccessSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: Colors.green,
    );
  }

  void showInfoSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: colorScheme.primary,
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
