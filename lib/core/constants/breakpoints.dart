class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  /// Below this height (landscape phones, desktop-site mode on phones) layouts
  /// should drop fixed chrome and shrink decorative elements.
  static const double compactHeight = 500;

  /// Max width of page content, so wide monitors don't stretch cards.
  static const double contentMaxWidth = 1200;

  /// Max width of single-column forms and form dialogs.
  static const double formMaxWidth = 560;

  /// Max width of list dialogs (accounts, categories, transactions).
  static const double listDialogMaxWidth = 900;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;

  static bool isMobileOrTablet(double width) => width < tablet;
  static bool isTabletOrDesktop(double width) => width >= mobile;

  static bool isCompactHeight(double height) => height < compactHeight;
}
