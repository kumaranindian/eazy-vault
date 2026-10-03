class AppConstants {
  const AppConstants._();

  static const String userCollection = 'users';
  static const String accountsCollection = 'accounts';
  static const String categoriesCollection = 'categories';
  static const String transactionsCollection = 'transactions';
  static const String budgetsCollection = 'budgets';
  static const String recurringTransactionsCollection = 'recurringTransactions';

  static const String profileDocument = 'profile';
  static const String settingsDocument = 'settings';

  static const String createdAtField = 'createdAt';
  static const String updatedAtField = 'updatedAt';
  static const String createdByField = 'createdBy';
  static const String isDeletedField = 'isDeleted';

  static const String sharedPrefsThemeMode = 'theme_mode';
  static const String sharedPrefsRememberMe = 'remember_me';
  static const String sharedPrefsLastEmail = 'last_email';
  static const String sharedPrefsNotificationsEnabled = 'notifications_enabled';
  static const String sharedPrefsNotifiedAlertKeys = 'notified_alert_keys';
  static const String sharedPrefsHasSeenGettingStarted =
      'has_seen_getting_started';
}

class RouteConstants {
  const RouteConstants._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String dashboard = '/dashboard';

  static const String accounts = '/accounts';
  static const String accountDetail = '/accounts/:id';
  static const String addAccount = '/accounts/add';
  static const String editAccount = '/accounts/:id/edit';

  static const String categories = '/categories';
  static const String addCategory = '/categories/add';
  static const String editCategory = '/categories/:id/edit';

  static const String transactions = '/transactions';
  static const String addIncome = '/transactions/add-income';
  static const String addExpense = '/transactions/add-expense';
  static const String transactionDetail = '/transactions/:id';
  static const String editTransaction = '/transactions/:id/edit';
  static const String importTransactions = '/transactions/import';

  static const String reports = '/reports';

  static const String settings = '/settings';
  static const String profile = '/profile';

  static const String about = '/about';

  static const String gettingStarted = '/getting-started';
  static const String userManual = '/manual';
}

class AssetConstants {
  const AssetConstants._();

  static const String logo = 'eazyvault_logo.png';
  static const String emptyTransactions =
      'assets/images/empty_transactions.svg';
  static const String emptyAccounts = 'assets/images/empty_accounts.svg';
  static const String emptyCategories = 'assets/images/empty_categories.svg';
  static const String errorIllustration = 'assets/images/error.svg';
}

/// Static company/brand facts shown on the About Us page. Centralized here
/// so none of it gets hand-typed into widgets — the registered office
/// address and email are legal/contact facts, not copy to improvise on.
class CompanyInfo {
  const CompanyInfo._();

  static const String companyName = 'Avail404 OPC Private Limited';
  static const String brandName = 'Avail404';
  static const String tagline = 'Make It Available';
  static const String email = 'hi@avail404.com';

  static const String officeAddressLabel =
      'Registered / Virtual Office Address';
  static const String officeAddress =
      'INNOV8 Millenia, 2nd Floor, East Wing, RMZ Millenia Business Park, '
      'Campus 1A.143, Dr. M.G.R. Road, N Veeranam Salai, Sholinganallur, '
      'Perungudi, Chennai, Tamil Nadu – 600096';
}

class ValidationConstants {
  const ValidationConstants._();

  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxVendorNameLength = 100;

  static const double minAmount = 0;
  static const double maxAmount = 999999999.99;
}
