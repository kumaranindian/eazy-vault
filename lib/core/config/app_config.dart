class AppConfig {
  const AppConfig._();

  static const String appName = 'EazyVault';
  static const String appTagline = 'Smart Finance Starts Here.';
  static const String appVersion = '1.0.0';

  static const int paginationLimit = 20;
  static const int defaultPageSize = 20;
  static const int searchDebounceMilliseconds = 500;
  static const int maxFileUploadSizeMB = 5;

  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration errorSnackbarDuration = Duration(seconds: 5);
  static const Duration loadingDebounce = Duration(milliseconds: 300);

  static const String defaultCurrency = '₹';
  static const String currencyCode = 'INR';
}
