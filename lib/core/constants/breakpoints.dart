class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;

  static bool isMobileOrTablet(double width) => width < tablet;
  static bool isTabletOrDesktop(double width) => width >= mobile;
}
